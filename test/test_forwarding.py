import sys, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from check_data import coefficients

class ForwardingTests(unittest.TestCase):
    def test_unequal_branching(self):
        # Three equal-cost paths; local ECMP differs from uniform path selection.
        links = [(0,1,1),(1,5,2),(0,2,1),(2,3,1),(3,5,1),(2,4,1),(4,5,1)]
        arcs = [dict(id=k,**{'from':u,'to':v},metric=w,capacity=1) for k,(u,v,w) in enumerate(links)]
        ec = coefficients(list(range(6)),arcs,set(),5,'ecmp')
        pu = coefficients(list(range(6)),arcs,set(),5,'path_uniform')
        self.assertAlmostEqual(ec[0,5][0],.5)
        self.assertAlmostEqual(pu[0,5][0],1/3)
        changed = coefficients(list(range(6)),arcs,{0},5,'ecmp')
        self.assertNotIn(0,changed[0,5])
        self.assertAlmostEqual(changed[0,5][2],1)
    def test_unreachable(self):
        self.assertNotIn((0,1),coefficients([0,1],[],set(),1,'ecmp'))

if __name__=='__main__': unittest.main()
