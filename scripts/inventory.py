"""Fast structural inventory; no all-pairs forwarding allocation."""
import csv, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
rows = []
for f in sorted((ROOT/'data/raw/SetA').glob('*-net.json')):
    prefix = str(f)[:-9]
    net = json.loads(f.read_text())
    tm = json.loads(Path(prefix+'-tm.json').read_text())
    sc = json.loads(Path(prefix+'-scenario.json').read_text())
    ids = {x['id'] for x in net['nodes']}
    arcids = {a['id'] for a in net['links']}
    assert len(ids)==len(net['nodes']) and len(arcids)==len(net['links'])
    assert all(a['from'] in ids and a['to'] in ids and a['metric']>0 and a['capacity']>0 for a in net['links'])
    assert all(d['s'] in ids and d['t'] in ids and len(d['v'])==tm['num_time_slots'] and min(d['v'])>=0 for d in tm['demands'])
    assert all(set(q['links']) <= arcids for q in sc['interventions'])
    rows.append(dict(instance=Path(prefix).name,nodes=len(ids),arcs=len(arcids),demands=len(tm['demands']),periods=tm['num_time_slots'],max_segments=sc['max_segments'],budget_t1=next((b['value'] for b in sc['budget'] if b['t']==1),None)))
out = ROOT/'results/tables/instances.csv'
out.parent.mkdir(parents=True,exist_ok=True)
with out.open('w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
print(f'Validated {len(rows)} instances; wrote {out}')
