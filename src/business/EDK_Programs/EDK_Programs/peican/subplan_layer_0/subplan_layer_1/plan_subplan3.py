from elements.common.wrappers import PLAN
from elements.core.plan import Plan
from elements.core.transit import Transit
from elements.examples.subplan_layer_0.subplan_layer_1.subplan_layer_2.plan_subplan4 import (
    plan_subplan4,
)


@PLAN
def plan_subplan3():
    plan = Plan(name="plan_subplan3")
    subplan4 = plan_subplan4()
    plan.add_subplan(subplan4)
    plan.start_node.add_transit(Transit(start=plan.start_node, end=subplan4))
    return plan
