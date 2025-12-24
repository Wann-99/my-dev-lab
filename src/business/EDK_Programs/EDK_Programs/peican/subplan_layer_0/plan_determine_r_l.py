from elements.common.enums import PrimitiveStateEnum, TransitConditionTypeEnum
from elements.common.wrappers import PLAN, TRANSIT
from elements.core.contrib.parameter_values import ParameterValueConstDouble
from elements.core.contrib.parameters import ParameterPtState
from elements.core.plan import Plan
from elements.core.primitives import Workflow
from elements.core.transit import Transit


@PLAN
def plan_determine_r_l() -> Plan:
    plan = Plan(name="DetermineR_L")
    hold_check = Workflow.Hold(name="DetermineCheck")
    end_determine = Workflow.End(name="EndDetermine")
    plan.add_primitive(hold_check)
    plan.add_primitive(end_determine)
    plan.start_node.add_transit(Transit(start=plan.start_node, end=hold_check))

    @TRANSIT
    def tr_hold_to_end(start, end) -> Transit:
        transit_hold_to_end = Transit(start, end)
        transit_hold_to_end.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=hold_check, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(0.1),
        )
        return transit_hold_to_end

    hold_check.add_transit(tr_hold_to_end(hold_check, end_determine))
    return plan

