import asyncio

from elements.common.enums import (
    PrimitiveInputParameterEnum,
    PrimitiveStateEnum,
    TransitConditionTypeEnum,
)
from elements.common.wrappers import TRANSIT
from elements.core.contrib.parameter_values import (
    ParameterValueConstBool,
    ParameterValueConstCoord,
)
from elements.core.contrib.parameters import ParameterPtState
from elements.core.plan import Plan
from elements.core.primitives import Motion, Workflow
from elements.core.transit import Transit
from elements.settings import RobotSetting


async def assign_project():
    """Create and assign project"""
    plan = Plan(name="test_assign", setting=RobotSetting(ip="127.0.0.1"))
    home0 = Workflow.Home(name="home0")
    plan.add_primitive(home0)
    movel0 = Motion.MoveL(name="movel0")
    movel0.add_parameter(
        param=PrimitiveInputParameterEnum.Motion.MoveL.Basic.Target,
        param_value=ParameterValueConstCoord(x=400, y=-400, z=400, ry=180),
    )
    plan.add_primitive(movel0)
    movec0 = Motion.MoveC(name="movec0")
    movec0.add_parameter(
        param=PrimitiveInputParameterEnum.Motion.MoveC.Basic.Target,
        param_value=ParameterValueConstCoord(x=400, y=400, z=400, ry=180),
    )
    movec0.add_parameter(
        param=PrimitiveInputParameterEnum.Motion.MoveC.Basic.MiddlePose,
        param_value=ParameterValueConstCoord(x=600, y=0, z=400, ry=180),
    )
    movec0.add_parameter(
        param=PrimitiveInputParameterEnum.Motion.MoveC.Advanced.EnableFixRefJntPos,
        param_value=ParameterValueConstBool(True),
    )
    plan.add_primitive(movec0)
    end0 = Workflow.End(name="end0")
    plan.add_primitive(end0)
    # add transition condition
    plan.start_node.add_transit(Transit(start=plan.start_node, end=home0))

    @TRANSIT
    def tr_home0_movel0() -> Transit:
        transit_home0_movel0 = Transit(start=home0, end=movel0)
        transit_home0_movel0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=home0, state=PrimitiveStateEnum.Home.ReachedTarget
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        return transit_home0_movel0

    home0.add_transit(tr_home0_movel0())

    @TRANSIT
    def tr_movel0_movec0() -> Transit:
        transit_movel0_movec0 = Transit(start=movel0, end=movec0)
        transit_movel0_movec0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=movel0, state=PrimitiveStateEnum.MoveL.ReachedTarget
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        return transit_movel0_movec0

    movel0.add_transit(tr_movel0_movec0())

    @TRANSIT
    def tr_movec0_end0() -> Transit:
        transit_movec0_end0 = Transit(start=movec0, end=end0)
        transit_movec0_end0.add_condition(
            condition_type=TransitConditionTypeEnum.EQUAL,
            lhs_param=ParameterPtState(
                pt=movec0, state=PrimitiveStateEnum.MoveC.ReachedTarget
            ),
            rhs_param=ParameterValueConstBool(value=True),
        )
        return transit_movec0_end0

    movec0.add_transit(tr_movec0_end0())
    await plan.assign()


if __name__ == "__main__":
    asyncio.run(assign_project())
