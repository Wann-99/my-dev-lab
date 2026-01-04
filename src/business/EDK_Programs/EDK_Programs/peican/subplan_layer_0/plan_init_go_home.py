from elements.common.enums import PrimitiveStateEnum, TransitConditionTypeEnum
from elements.common.wrappers import PLAN, TRANSIT
from elements.core.contrib.parameter_values import (
    ParameterValueConstBool,
    ParameterValueConstDouble,
)
from elements.core.contrib.parameters import ParameterPtState
from elements.core.plan import Plan
from elements.core.primitives import Workflow
from elements.core.transit import Transit


@PLAN
def plan_init_go_home() -> Plan:
    plan = Plan(name="Init_GoHome")
    modbus_init = Workflow.Hold(name="ModbusInit")
    to_home = Workflow.Home(name="ToHome")
    arrive_home = Workflow.Hold(name="ArriveHome")
    stop0 = Workflow.Hold(name="Stop0")
    plan.add_primitive(modbus_init)
    plan.add_primitive(to_home)
    plan.add_primitive(arrive_home)
    plan.add_primitive(stop0)
    plan.start_node.add_transit(Transit(start=plan.start_node, end=modbus_init))

    @TRANSIT
    def tr_modbus_to_home(start, end) -> Transit:
        transit_modbus_to_home = Transit(start, end)
        transit_modbus_to_home.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=modbus_init, state=PrimitiveStateEnum.Hold.Terminated
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        return transit_modbus_to_home

    modbus_init.add_transit(tr_modbus_to_home(modbus_init, to_home))

    @TRANSIT
    def tr_home_to_arrive(start, end) -> Transit:
        transit_home_to_arrive = Transit(start, end)
        transit_home_to_arrive.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=to_home, state=PrimitiveStateEnum.Home.ReachedTarget
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        return transit_home_to_arrive

    to_home.add_transit(tr_home_to_arrive(to_home, arrive_home))

    @TRANSIT
    def tr_arrive_to_stop(start, end) -> Transit:
        transit_arrive_to_stop = Transit(start, end)
        transit_arrive_to_stop.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=arrive_home, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(0.001),
        )
        return transit_arrive_to_stop

    arrive_home.add_transit(tr_arrive_to_stop(arrive_home, stop0))
    return plan

