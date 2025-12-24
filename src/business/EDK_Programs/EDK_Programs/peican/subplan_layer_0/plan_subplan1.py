from elements.common.enums import PrimitiveStateEnum, TransitConditionTypeEnum
from elements.common.wrappers import PLAN, TRANSIT
from elements.core.contrib.parameter_values import ParameterValueConstBool
from elements.core.contrib.parameters import ParameterPtState
from elements.core.plan import Plan
from elements.core.primitives import Workflow
from elements.core.transit import Transit


@PLAN
def plan_subplan1() -> Plan:
    plan = Plan("plan_subplan1")
    home0 = Workflow.Home(name="home0")
    end0 = Workflow.End(name="end0")
    plan.add_primitive(home0)
    plan.add_primitive(end0)
    plan.start_node.add_transit(Transit(plan.start_node, home0))

    @TRANSIT
    def tr_home0_end0(start, end) -> Transit:
        transit_home0_end0 = Transit(start, end)
        transit_home0_end0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=home0, state=PrimitiveStateEnum.Home.ReachedTarget
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        return transit_home0_end0

    home0.add_transit(tr_home0_end0(home0, end0))
    return plan
