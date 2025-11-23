from elements.common.enums import (
    PlanParameterEnum,
    PrimitiveStateEnum,
    TransitConditionTypeEnum,
    TransitOperationTypeEnum,
    VariableEnum,
)
from elements.common.wrappers import TRANSIT
from elements.core.contrib.parameter_values import (
    ParameterValueConstBool,
    ParameterValueConstDouble,
    ParameterValueConstInt,
    ParameterValueConstVEC7D,
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
from elements.core.variables import PlanVariable, ProjectVariable
from elements.examples.subplan_layer_0.plan_subplan1 import plan_subplan1
from elements.examples.subplan_layer_0.plan_subplan2 import plan_subplan2


def create_plan():
    """Create a plan"""
    plan = Plan(name="test_plan")
    return plan


def generate_plan_graph_and_file():
    """
    to_file: Generate .plan file,
    to_graph: Generate plan graph,
    to_project: Generate project folder
    """
    plan = Plan(name="generate_plan_file")
    # add primitives and transits
    home0 = Workflow.Home(name="Home0")
    end0 = Workflow.End(name="End0")
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
    # generate file/graph/project
    plan.to_file()
    plan.to_graph()
    plan.to_project()


def modify_plan_basic_configuration():
    """Modify plan description and plan logger configuration"""
    plan = Plan(name="plan_basic_configuration")
    # set the description
    plan.description = "test plan description."
    # enable plan logger
    plan.plan_logger_enabled = True
    # set "Sampling Period"
    plan.plan_logger_interval = 3
    # set "Max Logging Duration"
    plan.plan_logger_duration = 50
    return plan


def add_subplan():
    """Add subplan to the main plan"""
    plan = Plan(name="add_subplan")
    subplan = plan_subplan1()
    plan.add_subplan(subplan)
    plan.start_node.add_transit(Transit(start=plan.start_node, end=subplan))
    return plan


def modify_subplan_params():
    """Modify subplan input parameters"""
    plan = Plan(name="modify_subplan_params")
    subplan = plan_subplan1()
    subplan.add_parameter(
        param=PlanParameterEnum.Basic.RepeatTimes, param_value=ParameterValueConstInt(3)
    )
    subplan.add_parameter(
        param=PlanParameterEnum.Advanced.EnableForceLimit,
        param_value=ParameterValueConstBool(True),
    )
    subplan.add_parameter(
        param=PlanParameterEnum.Advanced.ForceLimit,
        param_value=ParameterValueConstDouble(10.0),
    )
    subplan.add_parameter(
        param=PlanParameterEnum.Advanced.EnableExtJntTrqLimit,
        param_value=ParameterValueConstBool(True),
    )
    subplan.add_parameter(
        param=PlanParameterEnum.Advanced.ExtJntTrqLimit,
        param_value=ParameterValueConstVEC7D(0.0, 1.0, 2.3, 4.5, 6.7, 8.9, 0.1),
    )
    plan.add_subplan(subplan)
    return plan


def add_subplans_include_subplans():
    """Add subplans include subplans"""
    plan = Plan(name="subplans_include_subplans")
    # add plan var
    pv_main_plan = PlanVariable(
        name="pv_main_plan",
        type=VariableEnum.VariableType.INT,
        value=VariableValueInt(1),
    )
    plan.add_plan_variable(pv_main_plan)
    # add proj var
    proj_int1 = ProjectVariable(
        name="proj_var1", type=VariableEnum.VariableType.INT, value=VariableValueInt(0)
    )
    plan.add_proj_variable(proj_int1)
    proj_int2 = ProjectVariable(
        name="proj_var2", type=VariableEnum.VariableType.INT, value=VariableValueInt(0)
    )
    plan.add_proj_variable(proj_int2)
    hold0 = Workflow.Hold(name="hold0")
    end0 = Workflow.End(name="end0")
    subplan1 = plan_subplan1()
    subplan2 = plan_subplan2(proj_int1)
    # add primitives and subplans
    plan.add_primitive(hold0)
    plan.add_primitive(end0)
    plan.add_subplan(subplan1)
    plan.add_subplan(subplan2)

    # add transitions
    plan.start_node.add_transit(Transit(plan.start_node, subplan1))

    @TRANSIT
    def tr_subplan1_hold0(start, end) -> Transit:
        transit_subplan1_hold0 = Transit(start, end)
        transit_subplan1_hold0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=subplan1, state=PrimitiveStateEnum.Subplan.Terminated
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        return transit_subplan1_hold0

    subplan1.add_transit(tr_subplan1_hold0(subplan1, hold0))

    @TRANSIT
    def tr_hold0_subplan2(start, end) -> Transit:
        transit_hold0_subplan2 = Transit(start, end)
        transit_hold0_subplan2.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=hold0, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(value=1.2),
        )
        return transit_hold0_subplan2

    subplan1.add_transit(tr_hold0_subplan2(hold0, subplan2))

    @TRANSIT
    def tr_subplan2_end0(start, end) -> Transit:
        transit_subplan2_end0 = Transit(start, end)
        transit_subplan2_end0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=subplan2, state=PrimitiveStateEnum.Subplan.Terminated
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        op = Operation(
            in_param_a=ParameterProjectVariable(prj_var=proj_int1),
            in_param_b=ParameterPlanVariable(plan_var=pv_main_plan),
            operator=TransitOperationTypeEnum.ADD,
            out_param=ParameterProjectVariable(prj_var=proj_int2),
        )
        transit_subplan2_end0.add_expression(operations=[op])
        return transit_subplan2_end0

    subplan2.add_transit(tr_subplan2_end0(subplan2, end0))
    return plan
