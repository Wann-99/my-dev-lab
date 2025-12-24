from elements.common.enums import PrimitiveStateEnum, TransitConditionTypeEnum
from elements.common.wrappers import PLAN, TRANSIT
from elements.core.contrib.parameter_values import ParameterValueConstDouble
from elements.core.contrib.parameters import ParameterPtState
from elements.core.plan import Plan
from elements.core.primitives import Workflow
from elements.core.transit import Transit


@PLAN
def plan_subplan4():
    plan = Plan(name="plan_subplan4")
    hold0 = Workflow.Hold(name="hold0")
    end0 = Workflow.End(name="end0")
    plan.add_primitive(hold0)
    plan.add_primitive(end0)
    plan.start_node.add_transit(Transit(plan.start_node, hold0))

    @TRANSIT
    def tr_hold0_end0(start, end) -> Transit:
        transit_hold0_end0 = Transit(start, end)
        transit_hold0_end0.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=hold0, state=PrimitiveStateEnum.Home.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(3),
        )
        return transit_hold0_end0

    hold0.add_transit(tr_hold0_end0(hold0, end0))
    return plan
