import copy,importlib.util,json,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('build_reference',ROOT/'build_reference.py');B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B)
class Tests(unittest.TestCase):
    def fixture(self):
        return dict(net=dict(directed=True,nodes=[dict(id=10),dict(id=20)],links=[dict(id=100,**{'from':10,'to':20},metric=.1,capacity=2.5)]),tm=dict(num_time_slots=2,demands=[dict(s=10,t=20,v=[7.5,99])]),scenario=dict(max_segments=6,interventions=[dict(t=1,links=[100])],budget=[dict(t=1,value=3)]))
    def run_case(self,objects):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'toy'
            for suffix,obj in objects.items():Path(str(p)+'-'+suffix+'.json').write_text(json.dumps(obj))
            return B.build(p,Path(d)/'ref.json')
    def test_period0_mapping_and_normalized_load(self):
        r=self.run_case(self.fixture());self.assertEqual(r['traffic'][0]['value'],'15/2');self.assertEqual(r['capacities'][0]['value'],'5/2');self.assertEqual(r['r_probes'][0]['load_coefficient_d0'],'3');self.assertEqual(r['MaxSeg'],6)
    def test_invalid_inputs_are_rejected(self):
        cases=[]
        o=self.fixture();o['net']['links'][0]['capacity']=0;cases.append(o)
        o=self.fixture();o['tm']['demands'][0]['v']=[-1,99];cases.append(o)
        o=self.fixture();o['tm']['demands'][0]['v']=[7.5];cases.append(o)
        o=self.fixture();o['scenario']['interventions']=[dict(t=0,links=[100])];cases.append(o)
        o=self.fixture();o['tm']['demands'][0]['s']=999;cases.append(o)
        o=self.fixture();o['scenario']['interventions']=[dict(t=1,links=[999])];cases.append(o)
        for o in cases:
            with self.subTest(data=o),self.assertRaises((ValueError,KeyError)):self.run_case(o)
if __name__=='__main__':unittest.main()
