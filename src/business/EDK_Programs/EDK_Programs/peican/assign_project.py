import asyncio

from elements.settings import RobotSetting

from .plan import plan_catering_2_1_1_251219rc


async def assign_project():
    setting = RobotSetting(ip="192.168.100.1")
    plan = plan_catering_2_1_1_251219rc(setting=setting)
    await plan.assign()


if __name__ == "__main__":
    asyncio.run(assign_project())
