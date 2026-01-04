from elements.common.enums import TransitConditionTypeEnum, GPIOStateEnum
from elements.common.wrappers import PLAN, TRANSIT
from elements.core.contrib.parameter_values import ParameterValueConstBool
from elements.core.contrib.parameters import ParameterGPIOState
from elements.core.plan import Plan
from elements.core.primitives import Workflow
from elements.core.transit import Transit


@PLAN
def plan_get_data() -> Plan:
    plan = Plan(name="GetData")
    hold_read = Workflow.Hold(name="ReadSensors")
    end_data = Workflow.End(name="EndGetData")
    plan.add_primitive(hold_read)
    plan.add_primitive(end_data)
    plan.start_node.add_transit(Transit(start=plan.start_node, end=hold_read))

    @TRANSIT
    def tr_hold_to_end(start, end) -> Transit:
        transit_hold_to_end = Transit(start, end)
        transit_hold_to_end.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterGPIOState.GPIOModbusTCPSlave(
                state=GPIOStateEnum.GPIOModbusTCPSlave.MTFloatIn20
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        return transit_hold_to_end

    hold_read.add_transit(tr_hold_to_end(hold_read, end_data))
    return plan

