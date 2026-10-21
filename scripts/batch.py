"""Sequential, resumable experiments. Failed runs get logs, never fake objectives."""
import json, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
config_path=Path(sys.argv[1] if len(sys.argv)>1 else 'config/smoke.json')
if not config_path.is_absolute(): config_path=ROOT/config_path
cfg=json.loads(config_path.read_text())
if shutil.which('julia') is None: sys.exit('Julia not found. Install Julia and run Pkg.instantiate() first.')
folder=ROOT/'results/raw'/config_path.stem
folder.mkdir(parents=True,exist_ok=True)
failed=0
for instance in cfg['instances']:
    for seed in range(1,cfg['runs']+1):
        out=folder/f'{instance}-{cfg["mode"]}-seed{seed}-{cfg["forwarding"]}.json'
        log=out.with_suffix('.log')
        if out.exists():
            previous=json.loads(out.read_text())
            if previous.get('time_limit_seconds') != cfg['time_limit_seconds']:
                sys.exit(f'Configuration changed for {out}; use a new config filename.')
            print('SKIP',out.name,flush=True);continue
        command=['julia','--project=.','scripts/run.jl',str(ROOT/'data/raw/SetA'/instance),cfg['mode'],str(cfg['time_limit_seconds']),str(seed),cfg['forwarding'],str(out)]
        print('RUN',out.name,flush=True)
        with log.open('w') as stream:
            completed=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        if completed.returncode:
            failed+=1
            print('FAILED; see',log,flush=True)
print(f'Finished. Failed executions: {failed}. Read logs and sample counts before reporting.')
sys.exit(1 if failed else 0)
