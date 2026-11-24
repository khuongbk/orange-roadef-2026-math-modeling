#!/usr/bin/env python3
import csv,hashlib,importlib.util,json
from fractions import Fraction
from pathlib import Path
ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('r_reference',ROOT/'compute_r_reference.py');R=importlib.util.module_from_spec(spec);spec.loader.exec_module(R)

def read_data(prefix):
    files={s:Path(str(prefix)+'-'+s+'.json') for s in ('net','tm','scenario')}
    net,tm,sc=[json.loads(files[s].read_text()) for s in files]
    graph=R.prepare(files['net']);ids,arcs,adj,scale,dist,sigma=graph;known=set(ids)
    capacity={a['id']:Fraction(str(a['capacity'])) for a in net['links']}
    if any(c<=0 for c in capacity.values()):raise ValueError('Capacity must be positive')
    if not isinstance(sc['max_segments'],int) or sc['max_segments']<1:raise ValueError('Invalid MaxSeg')
    horizon=tm['num_time_slots']
    if not isinstance(horizon,int) or horizon<1:raise ValueError('Invalid horizon')
    if not tm['demands']:raise ValueError('No demands')
    idx={v:i for i,v in enumerate(ids)}
    for d in tm['demands']:
        if d['s'] not in known or d['t'] not in known or d['s']==d['t']:raise ValueError('Invalid endpoints')
        if len(d['v'])!=horizon or any(Fraction(str(v))<0 for v in d['v']):raise ValueError('Invalid traffic')
        if not sigma[idx[d['s']]][idx[d['t']]]:raise ValueError('Unreachable demand')
    arc_ids=set(capacity)
    for q in sc['interventions']:
        if not 0<=q['t']<horizon or not set(q['links'])<=arc_ids:raise ValueError('Invalid intervention')
        if q['t']==0 and q['links']:raise ValueError('Period-0 intervention')
    if len({b['t'] for b in sc['budget']})!=len(sc['budget']):raise ValueError('Duplicate budget')
    if any(not 0<b['t']<horizon or b['value']<0 for b in sc['budget']):raise ValueError('Invalid budget')
    return files,net,tm,sc,graph

def build(prefix,output):
    files,net,tm,sc,graph=read_data(prefix);ids,arcs,adj,scale,dist,sigma=graph
    capacities=[dict(arc_id=a['id'],value=str(Fraction(str(a['capacity']))),metric=str(Fraction(str(a['metric'])))) for a in net['links']]
    traffic=[dict(d=k,source=d['s'],target=d['t'],value=str(Fraction(str(d['v'][0])))) for k,d in enumerate(tm['demands'])]
    d0=traffic[0];idx={v:k for k,v in enumerate(ids)};pair=(idx[d0['source']],idx[d0['target']])
    rr=R.ratios(graph,*pair);cap={a['id']:Fraction(str(a['capacity'])) for a in net['links']}
    selected=list(sorted(rr))[:10]+[a for a in cap if a not in rr][:2]
    probes=[dict(i=d0['source'],j=d0['target'],arc_id=a,value=str(rr.get(a,Fraction(0))),load_coefficient_d0=str(Fraction(d0['value'])*rr.get(a,Fraction(0))/cap[a])) for a in selected]
    ref=dict(instance=Path(prefix).name,period=0,vertices=len(ids),links=len(arcs),demands=len(traffic),MaxSeg=sc['max_segments'],vertex_ids=ids,input_sha256={s:hashlib.sha256(p.read_bytes()).hexdigest() for s,p in files.items()},capacities=capacities,traffic=traffic,r_probes=probes,total_traffic_period0=str(sum(Fraction(x['value']) for x in traffic)))
    Path(output).parent.mkdir(parents=True,exist_ok=True);Path(output).write_text(json.dumps(ref,indent=2))
    print(ref['instance'],ref['vertices'],ref['links'],ref['demands'],'MaxSeg',ref['MaxSeg'],'traffic0',ref['total_traffic_period0'])
    return ref
if __name__=='__main__':
    for tag in ('09','14'):build(ROOT/'data'/f'setA-{tag}',ROOT/'reference'/f'setA-{tag}-parameters.json')
