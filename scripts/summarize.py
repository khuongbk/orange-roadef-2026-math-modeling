"""Aggregate valid records without hiding missing incumbents or unfinished groups."""
import collections,csv,json,math,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
groups=collections.defaultdict(list)
for f in sorted((ROOT/'results/raw').rglob('*.json')):
    row=json.loads(f.read_text())
    key=(str(f.parent.relative_to(ROOT/'results/raw')),row.get('instance',f.name),tuple(row['periods']),row['forwarding'],row['time_limit_seconds'])
    groups[key].append(row)
rows=[]
for (experiment,instance,periods,forwarding,limit),records in groups.items():
    row=dict(experiment=experiment,instance=instance,periods='/'.join(map(str,periods)),forwarding=forwarding,limit=limit,runs_available=len(records),optimal_runs=sum(r['termination_status']=='OPTIMAL' for r in records),runs_with_incumbent=sum(r.get('objective') is not None for r in records),statuses=json.dumps(dict(collections.Counter(r['termination_status'] for r in records))))
    for key in ['objective','best_bound','gap','optimize_elapsed_seconds','bb_nodes']:
        values=[r[key] for r in records if isinstance(r.get(key),(int,float)) and math.isfinite(r[key])]
        row[key+'_samples']=len(values)
        row[key+'_mean']=statistics.mean(values) if values else None
    rows.append(row)
if not rows: print('No solver records yet.');raise SystemExit(0)
out=ROOT/'results/tables/summary.csv'
with out.open('w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
print(out)
