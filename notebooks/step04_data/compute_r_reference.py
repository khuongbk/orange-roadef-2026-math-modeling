#!/usr/bin/env python3
"""Exact period-0 path-uniform ratios. Standard library only, handles parallel arcs."""
import argparse,csv,hashlib,heapq,json,math,time
from fractions import Fraction
from pathlib import Path

def prepare(path):
    net=json.loads(Path(path).read_text());ids=[q['id'] for q in net['nodes']];idx={v:k for k,v in enumerate(ids)}
    if not net['directed'] or len(ids)!=len(idx):raise ValueError('Invalid directed graph or node IDs')
    metrics=[Fraction(str(a['metric'])) for a in net['links']]
    if any(w<=0 for w in metrics):raise ValueError('Positive metric required')
    scale=math.lcm(*(w.denominator for w in metrics));n=len(ids)
    arcs=[(a['id'],idx[a['from']],idx[a['to']],int(w*scale)) for a,w in zip(net['links'],metrics)]
    if len({a[0] for a in arcs})!=len(arcs):raise ValueError('Duplicate arc IDs')
    adj=[[] for _ in ids]
    for a,u,v,w in arcs:adj[u].append((v,w,a))
    dist=[];sigma=[]
    for s in range(n):
        ds=[None]*n;counts=[0]*n;ds[s]=0;counts[s]=1;q=[(0,s)]
        while q:
            length,u=heapq.heappop(q)
            if ds[u]!=length:continue
            for v,w,_ in adj[u]:
                nd=length+w
                if ds[v] is None or nd<ds[v]:ds[v]=nd;counts[v]=counts[u];heapq.heappush(q,(nd,v))
                elif nd==ds[v]:counts[v]+=counts[u]
        dist.append(ds);sigma.append(counts)
    return ids,arcs,adj,scale,dist,sigma

def ratios(R,i,j):
    ids,arcs,adj,scale,dist,sigma=R
    if not sigma[i][j]:raise ValueError('Unreachable segment')
    if i==j:return {}
    out={};ds=dist[i];counts=sigma[i];den=counts[j]
    for a,u,v,w in arcs:
        if ds[u] is not None and dist[v][j] is not None and ds[u]+w+dist[v][j]==ds[j]:out[a]=Fraction(counts[u]*sigma[v][j],den)
    return out

def export(path,folder):
    began=time.perf_counter();R=prepare(path);ids,arcs,adj,scale,dist,sigma=R;tag=Path(path).name.removesuffix('-net.json');folder=Path(folder);folder.mkdir(parents=True,exist_ok=True)
    n=len(ids);entries=0;pairs=0;fractions=0
    with (folder/f'{tag}-shortest-data.csv').open('w',newline='') as f:
        wr=csv.writer(f);wr.writerow(['i','j','reachable','distance','sigma'])
        for i in range(n):
            for j in range(n):
                if i!=j:wr.writerow([ids[i],ids[j],bool(sigma[i][j]),str(Fraction(dist[i][j],scale)) if dist[i][j] is not None else '',sigma[i][j]])
    with (folder/f'{tag}-r0-nonzero.csv').open('w',newline='') as f:
        wr=csv.writer(f);wr.writerow(['i','j','arc_id','r_numerator','r_denominator'])
        for i in range(n):
            for j in range(n):
                if i==j or not sigma[i][j]:continue
                rr=ratios(R,i,j);balance={};length=Fraction(0)
                for a,u,v,w in arcs:
                    r=rr.get(a)
                    if r is None:continue
                    if not 0<r<=1:raise AssertionError('r outside (0,1]')
                    balance[u]=balance.get(u,Fraction(0))+r;balance[v]=balance.get(v,Fraction(0))-r;length+=r*w
                    wr.writerow([ids[i],ids[j],a,r.numerator,r.denominator]);entries+=1;fractions+=r.denominator!=1
                balance={k:v for k,v in balance.items() if v}
                if balance!={i:1,j:-1} or length!=dist[i][j]:raise AssertionError(f'Flow/distance violation {i,j}')
                pairs+=1
            if (i+1)%50==0:print(tag,'source',i+1,'/',n,flush=True)
    report=dict(instance=tag,period=0,vertices=n,links=len(arcs),reachable_ordered_pairs=pairs,unreachable_ordered_pairs=sum(sigma[i][j]==0 for i in range(n) for j in range(n) if i!=j),pairs_with_multiple_shortest_paths=sum(sigma[i][j]>1 for i in range(n) for j in range(n)),maximum_shortest_path_count=max(map(max,sigma)),nonzero_coefficients=entries,fractional_nonzero_coefficients=fractions,all_reachable_pairs_checked=pairs,checks=['exact flow conservation','0 < nonzero r <= 1','sum(r * metric) == shortest distance'],arithmetic='exact rational coefficients; integer-scaled decimal metrics',forwarding='path_uniform per calculating_r.pdf',input_sha256=hashlib.sha256(Path(path).read_bytes()).hexdigest(),preprocessing_elapsed_seconds=time.perf_counter()-began)
    (folder/f'{tag}-r0-summary.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
    return report
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('net');ap.add_argument('--output',default='results/step03');a=ap.parse_args();export(a.net,a.output)
