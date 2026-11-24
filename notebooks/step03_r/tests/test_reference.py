import importlib.util,json,random,tempfile,unittest
from fractions import Fraction
from pathlib import Path
spec=importlib.util.spec_from_file_location('compute_r',Path(__file__).resolve().parents[1]/'compute_r.py');C=importlib.util.module_from_spec(spec);spec.loader.exec_module(C)

def enumerate_paths(adj,s,t):
    paths=[]
    def visit(u,seen,cost,arcs):
        if u==t:paths.append((cost,arcs));return
        for v,w,a in adj[u]:
            if v not in seen:visit(v,seen|{v},cost+w,arcs+[a])
    visit(s,{s},0,[])
    if not paths:return []
    cost=min(c for c,p in paths);return [p for c,p in paths if c==cost]
class Tests(unittest.TestCase):
    def test_600_pairs_against_enumeration_including_parallel_arcs(self):
        checked=0
        for seed in range(30):
            rng=random.Random(seed);ids=[10,20,40,70,100];links=[]
            for u in ids:
                for v in ids:
                    if u==v or rng.random()>.45:continue
                    for _ in range(1+(rng.random()<.2)):
                        links.append(dict(id=1000+len(links),**{'from':u,'to':v},metric=rng.choice(['0.1','0.2','0.3'])))
            with tempfile.TemporaryDirectory() as dd:
                p=Path(dd)/'net.json';p.write_text(json.dumps(dict(directed=True,nodes=[dict(id=i) for i in ids],links=links)));R=C.prepare(p)
                for i in range(len(ids)):
                    for j in range(len(ids)):
                        if i==j:continue
                        routes=enumerate_paths(R[2],i,j);self.assertEqual(R[-1][i][j],len(routes))
                        if not routes:
                            with self.assertRaises(ValueError):C.ratios(R,i,j)
                        else:
                            expected={a:Fraction(sum(a in p for p in routes),len(routes)) for a,_,_,_ in R[1]}
                            expected={a:r for a,r in expected.items() if r};self.assertEqual(C.ratios(R,i,j),expected)
                        checked+=1
        self.assertEqual(checked,600)
    def test_unequal_shortest_path_continuations(self):
        links=[(0,1,1),(0,2,1),(1,3,1),(1,4,1),(3,5,1),(4,5,1),(2,5,2)]
        net=dict(directed=True,nodes=[dict(id=i) for i in range(6)],links=[dict(id=a,**{'from':u,'to':v},metric=w) for a,(u,v,w) in enumerate(links)])
        with tempfile.TemporaryDirectory() as dd:
            p=Path(dd)/'toy.json';p.write_text(json.dumps(net));R=C.prepare(p);rr=C.ratios(R,0,5)
            self.assertEqual(rr[0],Fraction(2,3));self.assertEqual(rr[1],Fraction(1,3))
if __name__=='__main__':unittest.main()
