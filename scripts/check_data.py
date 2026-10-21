"""Independent forwarding/baseline audit. Standard-library Python only."""
import json, math, heapq, sys
from pathlib import Path

def coefficients(nodes, arcs, down, target, mode):
    incoming = {u: [] for u in nodes}
    outgoing = {u: [] for u in nodes}
    for a in arcs:
        if a['id'] not in down:
            incoming[a['to']].append(a)
            outgoing[a['from']].append(a)
    dist = {u: math.inf for u in nodes}
    dist[target] = 0
    queue = [(0, target)]
    while queue:
        value, v = heapq.heappop(queue)
        if value != dist[v]:
            continue
        for a in incoming[v]:
            u = a['from']; candidate = value + a['metric']
            if candidate < dist[u]:
                dist[u] = candidate
                heapq.heappush(queue, (candidate, u))
    next_hops = {u: [a for a in outgoing[u] if math.isfinite(dist[u]) and
                     math.isclose(a['metric']+dist[a['to']], dist[u], rel_tol=1e-12, abs_tol=1e-8)] for u in nodes}
    order = sorted(nodes, key=lambda u: dist[u], reverse=True)
    counts = {u: 0 for u in nodes}; counts[target] = 1
    for u in reversed(order):
        if u != target:
            counts[u] = sum(counts[a['to']] for a in next_hops[u])
    ratios = {}
    for source in nodes:
        if source == target or not math.isfinite(dist[source]):
            continue
        flow = {u: 0.0 for u in nodes}; flow[source] = 1.0
        uses = {}
        for u in order:
            for a in next_hops[u]:
                fraction = 1/len(next_hops[u]) if mode == 'ecmp' else counts[a['to']]/counts[u]
                amount = flow[u]*fraction
                uses[a['id']] = amount
                flow[a['to']] += amount
        assert math.isclose(flow[target], 1, abs_tol=1e-9)
        for u in nodes:
            balance = sum(uses.get(a['id'],0) for a in outgoing[u])-sum(uses.get(a['id'],0) for a in incoming[u])
            assert math.isclose(balance, int(u==source)-int(u==target), abs_tol=1e-9)
        ratios[source,target] = uses
    return ratios

def audit(prefix):
    net, tm, sc = [json.loads(Path(str(prefix)+suffix+'.json').read_text()) for suffix in ['-net','-tm','-scenario']]
    nodes = [n['id'] for n in net['nodes']]; arcs = net['links']
    assert len(set(nodes)) == len(nodes)
    assert len({a['id'] for a in arcs}) == len(arcs)
    assert len({(a['from'],a['to']) for a in arcs}) == len(arcs)
    assert all(a['from'] in nodes and a['to'] in nodes and a['metric']>0 and a['capacity']>0 for a in arcs)
    assert all(d['s'] in nodes and d['t'] in nodes and d['s']!=d['t'] and len(d['v'])==tm['num_time_slots'] and min(d['v'])>=0 for d in tm['demands'])
    report = {'nodes':len(nodes),'arcs':len(arcs),'demands':len(tm['demands']),'max_segments':sc['max_segments'],'periods':[]}
    allids = {a['id'] for a in arcs}
    for t in range(tm['num_time_slots']):
        down = set(a for q in sc['interventions'] if q['t']==t for a in q['links'])
        assert down <= allids
        modes = {mode: {} for mode in ['ecmp','path_uniform']}
        for mode in modes:
            for target in nodes:
                modes[mode].update(coefficients(nodes,arcs,down,target,mode))
        differences = sum(any(abs(modes['ecmp'][pair].get(a,0)-modes['path_uniform'][pair].get(a,0))>1e-9 for a in allids) for pair in modes['ecmp'])
        baseline = {}
        for mode, ratios in modes.items():
            loads = {a:0.0 for a in allids}
            for d in tm['demands']:
                assert (d['s'],d['t']) in ratios, 'Unreachable demand'
                for a, fraction in ratios[d['s'],d['t']].items():
                    loads[a] += d['v'][t]*fraction
            assert all(loads[a]==0 for a in down)
            ranked = sorted([(loads[a['id']]/a['capacity'], a['id']) for a in arcs if a['id'] not in down],reverse=True)
            baseline[mode] = {'mlu':ranked[0][0],'most_loaded_arc':ranked[0][1]}
        report['periods'].append({'t':t,'active_arcs':len(arcs)-len(down),'down_arc_ids':sorted(down),
            'total_traffic':sum(d['v'][t] for d in tm['demands']), 'reachable_ordered_pairs':len(modes['ecmp']),
            'pairs_with_different_forwarding':differences,'no_waypoint_baseline':baseline})
    return report

if __name__ == '__main__':
    prefix = Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]/'data/raw/SetA/setA-01'
    report = audit(prefix)
    output = Path(__file__).resolve().parents[1]/'results/data-audit.json'
    output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
