from elements.common.enums import (
    PrimitiveInputParameterEnum,
    PrimitiveOutputParameterEnum,
    SystemStateEnum,
    VariableEnum,
)
from elements.core.contrib.parameter_values import (
    ParameterValueConstDouble,
    ParameterValueConstInt,
    ParameterValueConstJPos,
    ParameterValuePlanVariable,
    ParameterValueProjectVariable,
)
from elements.core.contrib.parameters import (
    ParameterPtInput,
    ParameterPtOutput,
    ParameterSystemState,
)
from elements.core.plan import Plan
from elements.core.primitives import BasicForceControl, Motion, Workflow
from elements.core.variable_values import VariableValueDouble, VariableValueInt
from elements.core.variables import PlanVariable, ProjectVariable


def add_primitives():
    """Add primitives to the plan"""
    plan = Plan(name="add_primitives")
    # Workflow primitives
    home0 = Workflow.Home(name="Home0")
    plan.add_primitive(home0)
    # Basic Force Control primitives
    movel0 = BasicForceControl.ZeroFTSensor(name="ZeroFTSensor0")
    plan.add_primitive(movel0)

    return plan


def set_primitive_parameters_const():
    """Set primitive parameters(Const)"""
    plan = Plan(name="test_param_const")
    home0 = Workflow.Home(name="home0")
    home0.add_parameter(
        param=PrimitiveInputParameterEnum.Workflow.Home.Basic.Target,
        param_value=ParameterValueConstJPos(0, 40, 0, -90, 0, -40, 0),
    )
    home0.add_parameter(
        param=PrimitiveInputParameterEnum.Workflow.Home.Basic.JntVelScale,
        param_value=ParameterValueConstInt(15),
    )
    home0.add_parameter(
        param=PrimitiveInputParameterEnum.Workflow.Home.Advanced.JntAccMultiplier,
        param_value=ParameterValueConstDouble(2.1),
    )
    plan.add_primitive(home0)

    return plan


def set_primitive_parameters_var():
    """Set primitive parameters(Var)"""
    plan = Plan(name="test_param_var")
    # add vars
    plan_var = PlanVariable(
        name="plan_acc",
        type=VariableEnum.VariableType.DOUBLE,
        value=VariableValueDouble(2.3),
    )
    plan.add_plan_variable(plan_var)
    proj_var = ProjectVariable(
        name="proj_vel", type=VariableEnum.VariableType.INT, value=VariableValueInt(22)
    )
    plan.add_proj_variable(proj_var)
    # set params via variables
    home0 = Workflow.Home(name="home0")
    home0.add_parameter(
        param=PrimitiveInputParameterEnum.Workflow.Home.Basic.Target,
        param_value=ParameterSystemState(SystemStateEnum.JPOS),
    )
    home0.add_parameter(
        param=PrimitiveInputParameterEnum.Workflow.Home.Basic.JntVelScale,
        param_value=ParameterValueProjectVariable(proj_var),
    )
    home0.add_parameter(
        param=PrimitiveInputParameterEnum.Workflow.Home.Advanced.JntAccMultiplier,
        param_value=ParameterValuePlanVariable(plan_var),
    )
    plan.add_primitive(home0)

    movel0 = Motion.MoveL(name="movel1")
    movel0.add_parameter(
        param=PrimitiveInputParameterEnum.Motion.MoveL.Basic.Target,
        param_value=ParameterPtOutput(
            home0, PrimitiveOutputParameterEnum.Workflow.Home.TcpPoseOut
        ),
    )
    movel0.add_parameter(
        param=PrimitiveInputParameterEnum.Motion.MoveL.Advanced.Acc,
        param_value=ParameterPtInput(
            home0, PrimitiveInputParameterEnum.Workflow.Home.Advanced.JntAccMultiplier
        ),
    )
    plan.add_primitive(movel0)

    return plan
