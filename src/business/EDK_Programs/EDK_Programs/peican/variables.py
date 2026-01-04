from elements.common.enums import VariableEnum
from elements.core.plan import Plan
from elements.core.variable_values import (
    VariableValueArrayCoord,
    VariableValueArrayDouble,
    VariableValueArrayJPos,
    VariableValueArrayPose,
    VariableValueCoord,
    VariableValueDouble,
    VariableValueInt,
    VariableValueJPos,
    VariableValuePose,
    VariableValueVec3D,
    VariableValueVec3I,
)
from elements.core.variables import PlanVariable, ProjectVariable


def add_plan_variable():
    """Add plan variables to the plan"""
    plan = Plan(name="add_plan_var")
    # Normal
    pv_int = PlanVariable(
        name="pv_int", type=VariableEnum.VariableType.INT, value=VariableValueInt(5)
    )
    plan.add_plan_variable(pv_int)

    # Vector
    pv_vec_3d = PlanVariable(
        name="pv_vec_3d",
        type=VariableEnum.VariableType.VEC_3D,
        value=VariableValueVec3D(-1, -2, -3),
    )
    plan.add_plan_variable(pv_vec_3d)

    # Position - Support partial data input
    pv_coord = PlanVariable(
        name="pv_coord",
        type=VariableEnum.VariableType.COORD,
        value=VariableValueCoord(600, 300, 200, 180, 0, 180, "WORLD::WORLD_ORIGIN"),
    )
    plan.add_plan_variable(pv_coord)

    pv_pose = PlanVariable(
        name="pv_pose",
        type=VariableEnum.VariableType.POSE,
        value=VariableValuePose(500, 300, 500, 0, 180, 0),
    )
    plan.add_plan_variable(pv_pose)

    pv_jpos = PlanVariable(
        name="pv_jpos",
        type=VariableEnum.VariableType.JPOS,
        value=VariableValueJPos(a3=10),
    )
    plan.add_plan_variable(pv_jpos)

    # Array - Input data must be complete
    pv_array_double = PlanVariable(
        name="pv_array_double",
        type=VariableEnum.VariableType.ARRAY_DOUBLE,
        value=VariableValueArrayDouble([]),
    )
    plan.add_plan_variable(pv_array_double)

    pv_array_coord = PlanVariable(
        name="pv_array_coord",
        type=VariableEnum.VariableType.ARRAY_COORD,
        value=VariableValueArrayCoord(
            [
                [
                    100,
                    200,
                    300,
                    40,
                    50,
                    60,
                    "WORLD::WORLD_ORIGIN",
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    -1,
                    2,
                    3,
                    4,
                    5,
                    6,
                ],
                [
                    -100,
                    -2,
                    -300,
                    40,
                    50,
                    60,
                    "WORK::WorkCoord0",
                    -1,
                    -2,
                    -3,
                    4,
                    5,
                    6,
                    7,
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                ],
            ]
        ),
    )
    plan.add_plan_variable(pv_array_coord)

    return plan


def add_proj_variables():
    """Add project variables to the plan"""
    plan = Plan(name="add_project_var")
    # Normal
    proj_double = ProjectVariable(
        name="proj_double",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(1.2),
    )
    plan.add_proj_variable(proj_double)

    # Vector
    proj_vec_3i = ProjectVariable(
        name="proj_vec_3i",
        type=VariableEnum.VariableType.VEC_3I,
        value=VariableValueVec3I(-1, 2, 3),
    )
    plan.add_proj_variable(proj_vec_3i)

    # Position
    proj_coord = ProjectVariable(
        name="proj_coord",
        type=VariableEnum.VariableType.COORD,
        value=VariableValueCoord(
            0.1,
            0.2,
            0.3,
            180,
            0,
            180,
            "WORK::WorkCoord0",
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            0.1,
            0,
            0,
            0,
            0,
            0,
        ),
    )
    plan.add_proj_variable(proj_coord)

    proj_pose = ProjectVariable(
        name="proj_pose",
        type=VariableEnum.VariableType.POSE,
        value=VariableValuePose(rx=135.5),
    )
    plan.add_proj_variable(proj_pose)

    proj_jpos = ProjectVariable(
        name="proj_jpos",
        type=VariableEnum.VariableType.JPOS,
        value=VariableValueJPos(10, 20, 30, 40, 50, 60, 70),
    )
    plan.add_proj_variable(proj_jpos)

    # Array
    pj_array_pose = ProjectVariable(
        name="pj_array_pose",
        type=VariableEnum.VariableType.ARRAY_POSE,
        value=VariableValueArrayPose([[100, 200, 300, 40, 50, 60]]),
    )
    plan.add_proj_variable(pj_array_pose)

    pj_array_jpos = ProjectVariable(
        name="pj_array_jpos",
        type=VariableEnum.VariableType.ARRAY_JPOS,
        value=VariableValueArrayJPos(
            [
                [1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3, 4, 5],
                [-1, -2, -3, -4, -5, -6, -7, 0, -1, -2, -3, -4, -5],
            ]
        ),
    )
    plan.add_proj_variable(pj_array_jpos)
    return plan
