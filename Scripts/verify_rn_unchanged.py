#!/usr/bin/env python3
"""Read-only verification against the RN baseline captured before phase one."""
from pathlib import Path
import hashlib,json,sys,subprocess
native=Path(__file__).resolve().parent.parent
rn=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else native.parent/'coran-memoire'
baseline=json.loads((native/'Docs/react-native-baseline.json').read_text(encoding='utf-8'))
changed=[p for p,h in baseline['files'].items() if not (rn/p).is_file() or hashlib.sha256((rn/p).read_bytes()).hexdigest()!=h]
head=subprocess.check_output(['git','-c','safe.directory='+str(rn).replace('\\','/'),'-C',str(rn),'rev-parse','HEAD'],text=True).strip()
assert head==baseline['commit'],'RN HEAD changed'
assert not changed,'RN files changed: '+str(changed)
print('React Native intact: '+str(len(baseline['files']))+' tracked files, HEAD '+head)
