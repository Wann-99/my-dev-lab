from elements.common.enums import (
    AIStateEnum,
    DeviceStateEnum,
    GPIOStateEnum,
    ParameterTypeValueEnum,
    PlanInputEnum,
    PlanStateEnum,
    PrimitiveStateEnum,
    SystemStateEnum,
    TransitConditionTypeEnum,
    TransitOperationTypeEnum,
    VariableEnum,
)
from elements.common.wrappers import PLAN, TRANSIT
from elements.core.contrib.parameter_values import (
    ParameterValueConstBool,
    ParameterValueConstDouble,
    ParameterValueConstInt,
    ParameterValueConstType,
    ParameterValuePlanVariable,
    ParameterValueProjectVariable,
)
from elements.core.contrib.parameters import (
    ParameterAIState,
    ParameterDeviceState,
    ParameterGlobalVariable,
    ParameterGPIOState,
    ParameterPlanInput,
    ParameterPlanState,
    ParameterPlanVariable,
    ParameterProjectVariable,
    ParameterPtState,
    ParameterSystemState,
)
from elements.core.plan import Plan
from elements.core.primitives import Workflow
from elements.core.transit import Assignment, Condition, Operation, Transit
from elements.core.variable_values import (
    VariableValueBool,
    VariableValueDouble,
    VariableValueInt,
)
from elements.core.variables import PlanVariable, ProjectVariable


def add_transit():
    """Connect startNode to primitive"""
    plan = Plan(name="startnode_to_primitive")
    home0 = Workflow.Home(name="Home0")
    plan.add_primitive(home0)
    plan.start_node.add_transit(Transit(start=plan.start_node, end=home0))
    return plan


def add_single_pt_state_transition_condition_const():
    """Add single pt state transition condition(Const)"""
    # create plan
    plan = Plan(name="add_single_tc_pt_state_const")

    # define subplan
    @PLAN
    def plan_subplan(name: str) -> Plan:
        subplan = Plan(name=name)
        hold0 = Workflow.Hold(name="Hold0")
        end0 = Workflow.End(name="End0")
        subplan.add_primitive(hold0)
        subplan.add_primitive(end0)
        subplan.start_node.add_transit(Transit(start=subplan.start_node, end=hold0))

        # add transition in subplan
        @TRANSIT
        def tr_hold0_end0(start, end) -> Transit:
            transit_hold0_end0 = Transit(start, end)
            transit_hold0_end0.add_condition(
                condition_type=TransitConditionTypeEnum.GREATER,
                lhs_param=ParameterPtState(
                    pt=hold0, state=PrimitiveStateEnum.Hold.TimePeriod
                ),
                rhs_param=ParameterValueConstDouble(value=3.2),
            )

            return transit_hold0_end0

        hold0.add_transit(tr_hold0_end0(hold0, end0))
        return subplan

    # add primitives
    home0 = Workflow.Home(name="Home0")
    end0 = Workflow.End(name="End0")
    plan.add_primitive(home0)
    plan.add_primitive(end0)
    # add subplan
    subplan0 = plan_subplan(name="Subplan0")
    plan.add_subplan(subplan0)

    # add transitions
    plan.start_node.add_transit(Transit(start=plan.start_node, end=home0))

    @TRANSIT
    def tr_home0_subplan0(start, end) -> Transit:
        transit_home0_movej0 = Transit(start, end)
        transit_home0_movej0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=home0, state=PrimitiveStateEnum.Home.ReachedTarget
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        return transit_home0_movej0

    home0.add_transit(tr_home0_subplan0(home0, subplan0))

    @TRANSIT
    def tr_subplan0_end0(start, end) -> Transit:
        transit_subplan0_end0 = Transit(start, end)
        transit_subplan0_end0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=subplan0, state=PrimitiveStateEnum.Subplan.Terminated
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        return transit_subplan0_end0

    subplan0.add_transit(tr_subplan0_end0(subplan0, end0))
    return plan


def add_single_pt_state_transition_condition_var():
    """Add single pt state transition condition(Var)"""
    # create plan
    plan = Plan(name="add_single_tc_pt_state_var")
    # add primitives
    home0 = Workflow.Home(name="Home0")
    hold0 = Workflow.Hold(name="Hold0")
    end0 = Workflow.End(name="End0")
    plan.add_primitive(home0)
    plan.add_primitive(hold0)
    plan.add_primitive(end0)
    # add vars
    plan_var = PlanVariable(
        name="pv_bool",
        type=VariableEnum.VariableType.BOOL,
        value=VariableValueBool(True),
    )
    plan.add_plan_variable(plan_var)
    proj_var = ProjectVariable(
        name="proj_double",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(1.5),
    )
    plan.add_proj_variable(proj_var)
    # add transitions
    plan.start_node.add_transit(Transit(start=plan.start_node, end=home0))

    @TRANSIT
    def tr_home0_hold0(start, end) -> Transit:
        transit_home0_hold0 = Transit(start, end)
        transit_home0_hold0.add_condition(
            condition_type=TransitConditionTypeEnum.NOT_EQUAL,
            lhs_param=ParameterPtState(
                pt=home0, state=PrimitiveStateEnum.Home.Terminated
            ),
            rhs_param=ParameterValuePlanVariable(plan_var),
        )
        return transit_home0_hold0

    home0.add_transit(tr_home0_hold0(home0, hold0))

    @TRANSIT
    def tr_hold0_end0(start, end) -> Transit:
        transit_hold0_end0 = Transit(start, end)
        transit_hold0_end0.add_condition(
            condition_type=TransitConditionTypeEnum.LESS_EQUAL,
            lhs_param=ParameterPtState(
                pt=hold0, state=PrimitiveStateEnum.MoveJ.TimePeriod
            ),
            rhs_param=ParameterValueProjectVariable(proj_var),
        )
        return transit_hold0_end0

    hold0.add_transit(tr_hold0_end0(hold0, end0))
    return plan


def add_other_type_transition_conditions():
    """Add other type conditions in transition"""
    plan = Plan(name="add_tc_others")
    # add primitives
    home0 = Workflow.Home(name="Home0")
    end0 = Workflow.End(name="End0")
    plan.add_primitive(home0)
    plan.add_primitive(end0)
    # add var
    plan_var = PlanVariable(
        name="pv_bool",
        type=VariableEnum.VariableType.BOOL,
        value=VariableValueBool(True),
    )
    plan.add_plan_variable(plan_var)
    proj_var = ProjectVariable(
        name="proj_double",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(1.5),
    )
    plan.add_proj_variable(proj_var)
    # add transitions
    plan.start_node.add_transit(Transit(start=plan.start_node, end=home0))

    @TRANSIT
    def tr_other_transition_conditions() -> Transit:
        transit_home0_end0 = Transit(start=home0, end=end0)
        # DEVICE_STATE
        tc_device = Condition(
            condition_type=TransitConditionTypeEnum.GREATER_EQUAL,
            lhs_param=ParameterDeviceState.FlexivGN01(
                state=DeviceStateEnum.FlexivGN01StateEnum.Width
            ),
            rhs_param=ParameterValueConstDouble(value=0.3),
        )
        # AI_STATE
        tc_ai_state = Condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterAIState(AIStateEnum.AI_STATUS_CODE),
            rhs_param=ParameterValueConstType(
                ParameterTypeValueEnum.AIStateValueEnum.AIStatusCode.DISCONNECTED
            ),
        )
        # PLAN_INPUT
        tc_plan_input = Condition(
            condition_type=TransitConditionTypeEnum.LESS_EQUAL,
            lhs_param=ParameterPlanInput(PlanInputEnum.RepeatTimes),
            rhs_param=ParameterValueConstInt(1),
        )
        # PLAN_STATE
        tc_plan_state = Condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPlanState(state=PlanStateEnum.LoopCnt),
            rhs_param=ParameterValueConstInt(3),
        )
        # SYS_STATE
        tc_system_state = Condition(
            condition_type=TransitConditionTypeEnum.NOT_EQUAL,
            lhs_param=ParameterSystemState(SystemStateEnum.IS_FAULT),
            rhs_param=ParameterValueConstBool(value=False),
        )
        # GPIO_STATE
        tc_gpio_state = Condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterGPIOState.GPIOSystem(
                state=GPIOStateEnum.GPIOSystem.GPIOIn1
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        # PLAN_VAR
        tc_plan_var_state = Condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPlanVariable(plan_var),
            rhs_param=ParameterValueConstBool(True),
        )
        # PROJ_VAR
        tc_proj_var_state = Condition(
            condition_type=TransitConditionTypeEnum.LESS,
            lhs_param=ParameterProjectVariable(proj_var),
            rhs_param=ParameterValueConstDouble(2),
        )
        # GLOBAL_VAR
        tc_global_var_state = Condition(
            condition_type=TransitConditionTypeEnum.LESS_EQUAL,
            lhs_param=ParameterGlobalVariable("gv", VariableEnum.VariableType.DOUBLE),
            rhs_param=ParameterValueConstDouble(2),
        )
        transit_home0_end0.add_condition(condition_type=TransitConditionTypeEnum.OR)
        transit_home0_end0.cm_trigger_condition.cml_trigger_condition.extend(
            [
                tc_device,
                tc_plan_state,
                tc_plan_var_state,
                tc_proj_var_state,
                tc_system_state,
                tc_gpio_state,
                tc_ai_state,
                tc_plan_input,
                tc_global_var_state,
            ]
        )
        return transit_home0_end0

    home0.add_transit(tr_other_transition_conditions())
    return plan


def add_multiple_transition_conditions():
    """Add multiple condition in transition (including nested conditions)"""
    plan = Plan(name="add_mutiple_conditions")
    # add primitives
    home0 = Workflow.Home(name="Home0")
    hold0 = Workflow.Hold(name="Hold0")
    end0 = Workflow.End(name="End0")
    plan.add_primitive(home0)
    plan.add_primitive(hold0)
    plan.add_primitive(end0)

    # add transitions
    plan.start_node.add_transit(Transit(start=plan.start_node, end=home0))

    # home to hold (And)
    @TRANSIT
    def tr_home0_hold0(start, end) -> Transit:
        transit_home0_hold0 = Transit(start, end)
        tc1 = Condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=home0, state=PrimitiveStateEnum.Home.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(value=-5),
        )
        tc2 = Condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=home0, state=PrimitiveStateEnum.Home.ReachedTarget
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        transit_home0_hold0.add_condition(condition_type=TransitConditionTypeEnum.AND)
        transit_home0_hold0.cm_trigger_condition.cml_trigger_condition.extend(
            [tc1, tc2]
        )
        return transit_home0_hold0

    home0.add_transit(tr_home0_hold0(home0, hold0))

    # hold0 to end0 (OR + (AND + OR))
    @TRANSIT
    def tr_hold0_end0(start, end) -> Transit:
        transit_hold0_end0 = Transit(start, end)
        tc3 = Condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=hold0, state=PrimitiveStateEnum.Hold.Terminated
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        tc4 = Condition(
            condition_type=TransitConditionTypeEnum.LESS,
            lhs_param=ParameterPtState(
                pt=hold0, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(value=2.3),
        )
        tc5 = Condition(
            condition_type=TransitConditionTypeEnum.GREATER_EQUAL,
            lhs_param=ParameterPtState(
                pt=hold0, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(value=5.2),
        )
        tc6 = Condition(
            condition_type=TransitConditionTypeEnum.NOT_EQUAL,
            lhs_param=ParameterSystemState(SystemStateEnum.IS_FAULT),
            rhs_param=ParameterValueConstBool(value=False),
        )

        tc3_or_tc4 = Condition(
            condition_type=TransitConditionTypeEnum.OR, cml_trigger_condition=[tc3, tc4]
        )
        tc5_and_tc3_or_tc4 = Condition(
            condition_type=TransitConditionTypeEnum.AND,
            cml_trigger_condition=[tc3_or_tc4, tc5],
        )
        transit_hold0_end0.add_condition(condition_type=TransitConditionTypeEnum.OR)
        transit_hold0_end0.cm_trigger_condition.cml_trigger_condition.extend(
            [tc5_and_tc3_or_tc4, tc6]
        )

        return transit_hold0_end0

    home0.add_transit(tr_hold0_end0(hold0, end0))
    return plan


def add_variable_operation():
    """Add variable operation in transition"""
    plan = Plan(name="add_operations")
    home0 = Workflow.Home(name="Home0")
    end0 = Workflow.End(name="End0")
    plan.add_primitive(home0)
    plan.add_primitive(end0)
    # add vars
    plan_var = PlanVariable(
        name="pv_int", type=VariableEnum.VariableType.INT, value=VariableValueInt(1)
    )
    plan.add_plan_variable(plan_var)
    proj_var = ProjectVariable(
        name="proj_double",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(0),
    )
    plan.add_proj_variable(proj_var)

    # add transitions
    @TRANSIT
    def tr_startnode_home0(start, end) -> Transit:
        transit_startnode_home0 = Transit(start, end)
        transit_startnode_home0.add_expression(
            operations=[
                Operation(
                    in_param_a=ParameterValueConstInt(value=1),
                    in_param_b=ParameterValueConstInt(value=2),
                    operator=TransitOperationTypeEnum.ADD,
                    out_param=ParameterPlanVariable(plan_var=plan_var),
                ),
            ]
        )
        return transit_startnode_home0

    plan.start_node.add_transit(tr_startnode_home0(plan.start_node, home0))

    @TRANSIT
    def tr_home0_end0(start, end) -> Transit:
        transit_home0_end0 = Transit(start, end)
        op1 = Operation(
            in_param_a=ParameterPlanVariable(plan_var=plan_var),
            in_param_b=ParameterPlanVariable(plan_var=plan_var),
            operator=TransitOperationTypeEnum.MUL,
            out_param=ParameterPlanVariable(plan_var=plan_var),
        )
        op2 = Operation(
            in_param_a=ParameterProjectVariable(prj_var=proj_var),
            operator=TransitOperationTypeEnum.SIN,
            out_param=ParameterProjectVariable(prj_var=proj_var),
        )
        transit_home0_end0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=home0, state=PrimitiveStateEnum.Home.ReachedTarget
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        transit_home0_end0.add_expression(operations=[op1, op2])
        return transit_home0_end0

    home0.add_transit(tr_home0_end0(home0, end0))
    return plan


def add_variable_assignment():
    """"""
    plan = Plan(name="add_assignments")
    home0 = Workflow.Home(name="Home0")
    end0 = Workflow.End(name="End0")
    plan.add_primitive(home0)
    plan.add_primitive(end0)
    # add vars
    plan_var_int = PlanVariable(
        name="pv_int", type=VariableEnum.VariableType.INT, value=VariableValueInt(0)
    )
    plan.add_plan_variable(plan_var_int)
    plan_var_double = PlanVariable(
        name="pv_double",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(0),
    )
    plan.add_plan_variable(plan_var_double)
    proj_var = ProjectVariable(
        name="proj_double",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(0),
    )
    plan.add_proj_variable(proj_var)

    # add transitions
    @TRANSIT
    def tr_startnode_home0(start, end) -> Transit:
        transit_startnode_home0 = Transit(start, end)
        assignment1 = Assignment(
            lhs_param=ParameterPlanVariable(plan_var=plan_var_int),
            rhs_param=ParameterValueConstInt(value=0),
        )
        assignment2 = Assignment(
            lhs_param=ParameterProjectVariable(prj_var=proj_var),
            rhs_param=ParameterValuePlanVariable(plan_var=plan_var_int),
        )
        transit_startnode_home0.add_expression(assignments=[assignment1, assignment2])
        return transit_startnode_home0

    plan.start_node.add_transit(tr_startnode_home0(plan.start_node, home0))

    @TRANSIT
    def tr_home0_end0(start, end) -> Transit:
        transit_home0_end0 = Transit(start, end)
        transit_home0_end0.add_expression(
            assignments=[
                Assignment(
                    lhs_param=ParameterPlanVariable(plan_var=plan_var_double),
                    rhs_param=ParameterValueProjectVariable(prj_var=proj_var),
                )
            ]
        )
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
