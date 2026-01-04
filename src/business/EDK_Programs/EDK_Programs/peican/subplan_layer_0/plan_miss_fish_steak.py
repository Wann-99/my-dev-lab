from elements.common.enums import PrimitiveStateEnum, TransitConditionTypeEnum
from elements.common.wrappers import PLAN, TRANSIT
from elements.core.contrib.parameter_values import ParameterValueConstDouble
from elements.core.contrib.parameters import ParameterPtState
from elements.core.plan import Plan
from elements.core.primitives import Workflow
from elements.core.transit import Transit


@PLAN
def plan_miss_fish_steak() -> Plan:
    plan = Plan(name="MissFishSteak")
    hold_wait = Workflow.Hold(name="WaitMiss")
    end_miss = Workflow.End(name="EndMiss")
    plan.add_primitive(hold_wait)
    plan.add_primitive(end_miss)
    plan.start_node.add_transit(Transit(start=plan.start_node, end=hold_wait))

    @TRANSIT
    def tr_wait_to_end(start, end) -> Transit:
        transit_wait_to_end = Transit(start, end)
        transit_wait_to_end.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=hold_wait, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(0.1),
        )
        return transit_wait_to_end

    hold_wait.add_transit(tr_wait_to_end(hold_wait, end_miss))
    return plan

