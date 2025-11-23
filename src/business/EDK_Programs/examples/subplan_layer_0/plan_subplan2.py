from elements.common.enums import (
    PrimitiveStateEnum,
    TransitConditionTypeEnum,
    TransitOperationTypeEnum,
    VariableEnum,
)
from elements.common.wrappers import PLAN, TRANSIT
from elements.core.contrib.parameter_values import (
    ParameterValueConstBool,
    ParameterValueConstDouble,
    ParameterValueConstInt,
)
from elements.core.contrib.parameters import (
    ParameterPlanVariable,
    ParameterProjectVariable,
    ParameterPtState,
)
from elements.core.plan import Plan
from elements.core.primitives import Workflow
from elements.core.transit import Operation, Transit
from elements.core.variable_values import VariableValueInt
from elements.core.variables import PlanVariable
from elements.examples.subplan_layer_0.subplan_layer_1.plan_subplan3 import (
    plan_subplan3,
)


@PLAN
def plan_subplan2(proj_var):
    plan = Plan(name="plan_subplan2")
    hold0 = Workflow.Hold(name="hold0")
    home0 = Workflow.Home(name="home0")
    end0 = Workflow.End(name="end0")
    subplan3 = plan_subplan3()
    # add primitives and subplans
    plan.add_primitive(hold0)
    plan.add_primitive(home0)
    plan.add_primitive(end0)
    plan.add_subplan(subplan3)
    # add plan var
    pv_subplan2 = PlanVariable(
        name="pv_subplan2",
        type=VariableEnum.VariableType.INT,
        value=VariableValueInt(2),
    )
    plan.add_plan_variable(pv_subplan2)
    # add transitions
    plan.start_node.add_transit(Transit(plan.start_node, hold0))

    @TRANSIT
    def tr_hold0_subplan3(start, end) -> Transit:
        transit_hold0_subplan3 = Transit(start, end)
        transit_hold0_subplan3.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=hold0, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(value=1),
        )
        return transit_hold0_subplan3

    hold0.add_transit(tr_hold0_subplan3(hold0, subplan3))

    @TRANSIT
    def tr_hold0_home0(start, end) -> Transit:
        transit_hold0_home0 = Transit(start, end)
        transit_hold0_home0.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=hold0, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(value=3),
        )
        return transit_hold0_home0

    hold0.add_transit(tr_hold0_home0(hold0, home0))

    @TRANSIT
    def tr_subplan3_end0(start, end) -> Transit:
        transit_subplan3_end0 = Transit(start, end)
        transit_subplan3_end0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=subplan3, state=PrimitiveStateEnum.Subplan.Terminated
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        op = Operation(
            in_param_a=ParameterValueConstInt(3),
            in_param_b=ParameterPlanVariable(plan_var=pv_subplan2),
            operator=TransitOperationTypeEnum.ADD,
            out_param=ParameterProjectVariable(prj_var=proj_var),
        )
        transit_subplan3_end0.add_expression(operations=[op])
        return transit_subplan3_end0

    subplan3.add_transit(tr_subplan3_end0(subplan3, end0))

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
