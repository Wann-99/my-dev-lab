from elements.common.enums import (
    PlanParameterEnum,
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
    ParameterValueConstVEC7D,
)
from elements.core.contrib.parameters import (
    ParameterGlobalVariable,
    ParameterPlanVariable,
    ParameterProjectVariable,
    ParameterPtState,
)
from elements.core.plan import Plan
from elements.core.primitives import BasicForceControl, Workflow
from elements.core.transit import Operation, Transit
from elements.core.variable_values import VariableValueInt, VariableValueDouble
from elements.core.variables import PlanVariable, ProjectVariable
from .subplan_layer_0.plan_init_go_home import plan_init_go_home
from .subplan_layer_0.plan_determine_r_l import plan_determine_r_l
from .subplan_layer_0.plan_miss_fish_steak import plan_miss_fish_steak
from .subplan_layer_0.plan_get_data import plan_get_data


@PLAN
def plan_catering_2_1_1_251224rc(setting=None) -> Plan:
    if setting is not None:
        plan = Plan(name="Catering_2-1-1_251219RC", setting=setting)
    else:
        plan = Plan(name="Catering_2-1-1_251219RC")

    pv_pick_index = PlanVariable(
        name="noneUnitPickIdx",
        type=VariableEnum.VariableType.INT,
        value=VariableValueInt(0),
    )
    plan.add_plan_variable(pv_pick_index)

    pv_down_vel = PlanVariable(
        name="noneUnitDownVel",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(0.0),
    )
    plan.add_plan_variable(pv_down_vel)

    pv_offset_length = PlanVariable(
        name="noneUnitOffsetLength",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(0.0),
    )
    plan.add_plan_variable(pv_offset_length)

    pv_contact_pos_x = PlanVariable(
        name="noneUnitContactPosX",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(0.0),
    )
    plan.add_plan_variable(pv_contact_pos_x)

    pv_contact_pos_y = PlanVariable(
        name="noneUnitContactPosY",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(0.0),
    )
    plan.add_plan_variable(pv_contact_pos_y)

    proj_counter = ProjectVariable(
        name="proj_counter",
        type=VariableEnum.VariableType.INT,
        value=VariableValueInt(0),
    )
    plan.add_proj_variable(proj_counter)

    finished_fix = Workflow.Hold(name="FinishedFix")
    calc_pick_pose = Workflow.Hold(name="CalcPickPose")
    move_comp = BasicForceControl.MoveCompliance(name="MoveComp0")
    absorb = Workflow.Hold(name="Absorb")
    to_meet_point = Workflow.Hold(name="ToMeetPoint")
    end_plan = Workflow.End(name="End")

    init_go_home = plan_init_go_home()
    init_go_home.add_parameter(
        param=PlanParameterEnum.Basic.RepeatTimes,
        param_value=ParameterValueConstInt(1),
    )
    init_go_home.add_parameter(
        param=PlanParameterEnum.Advanced.EnableForceLimit,
        param_value=ParameterValueConstBool(False),
    )
    init_go_home.add_parameter(
        param=PlanParameterEnum.Advanced.ForceLimit,
        param_value=ParameterValueConstDouble(500.0),
    )
    init_go_home.add_parameter(
        param=PlanParameterEnum.Advanced.EnableExtJntTrqLimit,
        param_value=ParameterValueConstBool(False),
    )
    init_go_home.add_parameter(
        param=PlanParameterEnum.Advanced.ExtJntTrqLimit,
        param_value=ParameterValueConstVEC7D(
            200.0,
            200.0,
            200.0,
            200.0,
            200.0,
            200.0,
            200.0,
        ),
    )
    determine_r_l = plan_determine_r_l()
    miss_fish_steak = plan_miss_fish_steak()
    get_data = plan_get_data()

    plan.add_primitive(finished_fix)
    plan.add_primitive(calc_pick_pose)
    plan.add_primitive(move_comp)
    plan.add_primitive(absorb)
    plan.add_primitive(to_meet_point)
    plan.add_primitive(end_plan)

    plan.add_subplan(init_go_home)
    plan.add_subplan(determine_r_l)
    plan.add_subplan(miss_fish_steak)
    plan.add_subplan(get_data)

    plan.start_node.add_transit(Transit(start=plan.start_node, end=init_go_home))

    @TRANSIT
    def tr_init_to_finished(start, end) -> Transit:
        transit_init_to_finished = Transit(start, end)
        transit_init_to_finished.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=init_go_home, state=PrimitiveStateEnum.Subplan.Terminated
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        return transit_init_to_finished

    init_go_home.add_transit(
        tr_init_to_finished(start=init_go_home, end=finished_fix)
    )

    @TRANSIT
    def tr_finished_to_determine(start, end) -> Transit:
        transit_finished_to_determine = Transit(start, end)
        transit_finished_to_determine.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=finished_fix, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(0.001),
        )
        return transit_finished_to_determine

    finished_fix.add_transit(
        tr_finished_to_determine(start=finished_fix, end=determine_r_l)
    )

    @TRANSIT
    def tr_determine_to_calc(start, end) -> Transit:
        transit_determine_to_calc = Transit(start, end)
        transit_determine_to_calc.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=determine_r_l, state=PrimitiveStateEnum.Subplan.Terminated
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        return transit_determine_to_calc

    determine_r_l.add_transit(
        tr_determine_to_calc(start=determine_r_l, end=calc_pick_pose)
    )

    @TRANSIT
    def tr_calc_to_move(start, end) -> Transit:
        transit_calc_to_move = Transit(start, end)
        transit_calc_to_move.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=calc_pick_pose, state=PrimitiveStateEnum.Hold.Terminated
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        return transit_calc_to_move

    calc_pick_pose.add_transit(tr_calc_to_move(start=calc_pick_pose, end=move_comp))

    @TRANSIT
    def tr_move_to_absorb(start, end) -> Transit:
        transit_move_to_absorb = Transit(start, end)
        transit_move_to_absorb.add_condition(
            condition_type=TransitConditionTypeEnum.LESS_EQUAL,
            lhs_param=ParameterGlobalVariable(
                "GripOrAbsorb", VariableEnum.VariableType.INT
            ),
            rhs_param=ParameterValueConstInt(0),
        )
        return transit_move_to_absorb

    move_comp.add_transit(tr_move_to_absorb(start=move_comp, end=absorb))

    @TRANSIT
    def tr_absorb_to_meet(start, end) -> Transit:
        transit_absorb_to_meet = Transit(start, end)
        transit_absorb_to_meet.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=absorb, state=PrimitiveStateEnum.Hold.Terminated
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        return transit_absorb_to_meet

    absorb.add_transit(
        tr_absorb_to_meet(start=absorb, end=to_meet_point)
    )

    @TRANSIT
    def tr_meet_to_get_data(start, end) -> Transit:
        transit_meet_to_get_data = Transit(start, end)
        transit_meet_to_get_data.add_condition(
            condition_type=TransitConditionTypeEnum.GREATER,
            lhs_param=ParameterPtState(
                pt=to_meet_point, state=PrimitiveStateEnum.Hold.TimePeriod
            ),
            rhs_param=ParameterValueConstDouble(0.001),
        )
        return transit_meet_to_get_data

    to_meet_point.add_transit(
        tr_meet_to_get_data(start=to_meet_point, end=get_data)
    )

    @TRANSIT
    def tr_get_data_to_end(start, end) -> Transit:
        transit_get_data_to_end = Transit(start, end)
        transit_get_data_to_end.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=get_data, state=PrimitiveStateEnum.Subplan.Terminated
            ),
            rhs_param=ParameterValueConstBool(True),
        )
        op = Operation(
            in_param_a=ParameterPlanVariable(plan_var=pv_pick_index),
            in_param_b=ParameterProjectVariable(prj_var=proj_counter),
            operator=TransitOperationTypeEnum.ADD,
            out_param=ParameterProjectVariable(prj_var=proj_counter),
        )
        transit_get_data_to_end.add_expression(operations=[op])
        return transit_get_data_to_end

    get_data.add_transit(
        tr_get_data_to_end(start=get_data, end=end_plan)
    )

    return plan
