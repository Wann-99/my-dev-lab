from enum import Enum


class PrimitiveEnum:
    class AdvancedForceControl:
        class ContactAlign:
            PT_NAME = "AlignContact"
            PT_TYPE = "ALIGNCONTACT"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                AlignContacted = "alignContacted"
                ForwardDis = "insertDis"

            class InputParams:
                class Basic(Enum):
                    ContactAxis = "contactDir"
                    ContactVel = "freeSpaceVel"
                    ContactForce = "targetForce"
                    AlignAxis = "alignmentDir"
                    AlignVelScale = "alignVelScale"

                class Advanced(Enum):
                    DeadbandScale = "deadbandScale"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class ForceTraj:
            PT_NAME = "MoveTraj"
            PT_TYPE = "MOVE_TRAJ"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    TrajFileName = "fileName"
                    TargetTolerLevel = "targetTolLevel"
                    ForceCoord = "forceCoord"
                    ForceAxis = "forceAxis"

                class Advanced(Enum):
                    ConfigOptObj = "nullspaceGradientScaling"
                    MaxVelForceDir = "maxVelForceDir"
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    Jerk = "maxJerk"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class ForceHybrid:
            PT_NAME = "MoveHybrid"
            PT_TYPE = "MOVEHYBRID"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    Waypoints = "waypoints"
                    Wrench = "wrench"
                    Vel = "maxVel"
                    ZoneRadius = "zoneRadius"
                    TargetTolerLevel = "targetTolLevel"
                    ForceCoord = "forceCoord"
                    ForceAxis = "forceAxis"
                    TargetWrench = "goalWrench"
                    StiffScale = "stiffnessScaling"

                class Advanced(Enum):
                    Acc = "maxAcc"
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    Jerk = "maxJerk"
                    ConfigOptObj = "nullspaceGradientScaling"
                    EnableMaxWrench = "enableMaxContactWrench"
                    MaxContactWrench = "maxContactWrench"
                    MaxVelForceDir = "maxVelForceDir"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class ForceComp:
            PT_NAME = "ForceCompliance"
            PT_TYPE = "MOVE_COMPLIANCE"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    Waypoints = "waypoints"
                    Vel = "maxVel"
                    ZoneRadius = "zoneRadius"
                    TargetTolerLevel = "targetTolLevel"
                    CompCoord = "compCoord"
                    StiffScale = "stiffnessScaling"

                class Advanced(Enum):
                    EnableMaxWrench = "enableMaxContactWrench"
                    MaxContactWrench = "maxContactWrench"
                    Acc = "maxAcc"
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    Jerk = "maxJerk"
                    ConfigOptObj = "nullspaceGradientScaling"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class BasicForceControl:
        class ZeroFTSensor:
            PT_NAME = "CaliForceSensor"
            PT_TYPE = "CALIFORCESENSOR"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"

            class InputParams:
                class Basic(Enum):
                    DataCollectTime = "dataCollectionTime"
                    EnableStaticCheck = "enableStaticCheck"

                class Advanced(Enum):
                    CalibExtraPayload = "calibrateExtraLoad"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class Contact:
            PT_NAME = "Contact"
            PT_TYPE = "CONTACT"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                CurContactForce = "curContactForce"
                ForwardDis = "insertDis"

            class InputParams:
                class Basic(Enum):
                    ContactCoord = "coord"
                    ContactDir = "movingDir"
                    ContactVel = "contactVel"
                    MaxContactForce = "maxContactForce"
                    EnableFineContact = "fineContactMode"

                class Advanced(Enum):
                    Waypoints = "waypoints"
                    Vel = "maxVel"
                    Acc = "maxAcc"
                    ZoneRadius = "zoneRadius"
                    Jerk = "maxJerk"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class ForceHybridLite:
            PT_NAME = "MoveHybridLite"
            PT_TYPE = "MOVEHYBRID"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    Waypoints = "waypoints"
                    Vel = "maxVel"
                    ZoneRadius = "zoneRadius"
                    TargetTolerLevel = "targetTolLevel"
                    ForceAxis = "forceAxis"
                    TargetWrench = "goalWrench"
                    StiffScale = "stiffnessScaling"

                class Advanced(Enum):
                    Acc = "maxAcc"
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    Jerk = "maxJerk"
                    ConfigOptObj = "nullspaceGradientScaling"
                    MaxVelForceDir = "maxVelForceDir"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class ForceCompLite:
            PT_NAME = "MoveCompliance"
            PT_TYPE = "MOVE_COMPLIANCE"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    Waypoints = "waypoints"
                    Vel = "maxVel"
                    ZoneRadius = "zoneRadius"
                    TargetTolerLevel = "targetTolLevel"
                    CompCoord = "compCoord"
                    CompAxis = "compAxis"

                class Advanced(Enum):
                    Acc = "maxAcc"
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    Jerk = "maxJerk"
                    ConfigOptObj = "nullspaceGradientScaling"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class AdaptiveAssembly:
        class SearchHole:
            PT_NAME = "SearchHole"
            PT_TYPE = "SEARCH_HOLE"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                SearchResisForce = "searchResistanceForce"
                PushDis = "timePeriod"
                ForceDrop = "forceDrop"
                LostContact = "lostContact"

            class InputParams:
                class Basic(Enum):
                    ContactAxis = "contactAxis"
                    ContactForce = "contactForce"
                    SearchAxis = "searchAxis"
                    SearchPattern = "patternType"
                    SpiralRadius = "radius"
                    ZigZagLength = "length"
                    ZigZagWidth = "height"
                    StartDensity = "startDensity"
                    TimeFactor = "timeFactor"
                    WiggleRange = "wiggleRange"
                    WigglePeriod = "wigglePeriod"

                class Advanced(Enum):
                    EnableMaxWrench = "enableMaxContactWrench"
                    MaxContactWrench = "maxContactWrench"
                    SearchImmed = "startSearchImmediately"
                    SearchStiffRatio = "searchStiffnessRatio"
                    MaxVelForceDir = "forceCtrlVelLimit"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class CheckPiH:
            PT_NAME = "PihCheckTran"
            PT_TYPE = "PIH_CHECK_TRAN"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                CheckComplete = "checkComplete"
                PegIsInHole = "pegIsInHole"

            class InputParams:
                class Basic(Enum):
                    ContactAxis = "contactAxis"
                    SearchAxis = "searchAxis"
                    SearchRange = "searchRange"
                    SearchForce = "searchForce"
                    SearchVel = "searchVelocity"

                class Advanced(Enum):
                    LinearSearchOnly = "lineSearchOnly"
                    ReturnToInitPose = "returnToInitPose"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"
                InitTcpPose = "initTcpPose"

        class InsertComp:
            PT_NAME = "Sleeve"
            PT_TYPE = "SLEEVE"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                IsMoving = "isMoving"
                InsertDis = "insertDis"

            class InputParams:
                class Basic(Enum):
                    InsertAxis = "insertDir"
                    CompAxis = "alignmentDir"
                    MaxContactForce = "maxContactForce"
                    InsertVel = "insertVel"

                class Advanced(Enum):
                    DeadbandScale = "deadbandScale"
                    CompVelScale = "adjustVelScale"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class Mate:
            PT_NAME = "Mating"
            PT_TYPE = "MATING"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                MatingFinish = "matingFinished"

            class InputParams:
                class Basic(Enum):
                    ContactAxis = "forceDir"
                    StiffScale = "stiffnessScaling"
                    ContactForce = "matingForce"
                    MatingAxis = "matingDir"
                    SlideMatingRange = "linearMatingRange"
                    SlideMatingVel = "maxLinearMatingVel"
                    SlideMatingAcc = "maxLinearMatingAcc"
                    RotateMatingRange = "angularMatingRange"
                    RotateMatingVel = "maxAngularMatingVel"
                    RotateMatingAcc = "maxAngularMatingAcc"
                    MatingTimes = "totalMatingTimes"
                    MaxContactDis = "maxMotionDisInForceDir"
                    SafetyForce = "safetyForce"

                class Advanced(Enum):
                    AddMatingAxis = "rasterDir"
                    AddSlideMatingRange = "linearRasterRange"
                    AddSlideMatingVel = "maxLinearRasterVel"
                    AddSlideMatingAcc = "maxLinearRasterAcc"
                    AddRotateMatingRange = "angularRasterRange"
                    AddRotateMatingVel = "maxAngularRasterVel"
                    AddRotateMatingAcc = "maxAngularRasterAcc"
                    MaxVelForceDir = "maxVelInForceDir"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class FastenScrew:
            PT_NAME = "ScrewFasten"
            PT_TYPE = "SCREWFASTEN"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                InsertDis = "insertDis"
                InsertVel = "insertVel"
                FastenState = "fastenState"
                ReachedHole = "reachedScrewHole"

            class InputParams:
                class Basic(Enum):
                    InsertDir = "insertDir"
                    MaxInsertVel = "insertVel"
                    InsertForce = "maxContactForce"
                    StiffScale = "stiffnessScale"

                class Advanced(Enum):
                    DiScrewInHole = "ioScrewInHole"
                    DiFastenFinish = "ioFinish"
                    DiScrewJam = "ioScrewJam"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class Motion:
        class MoveC:
            PT_NAME = "MoveC"
            PT_TYPE = "MOVEC"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    MiddlePose = "middlePose"
                    Vel = "maxVel"
                    TargetTolerLevel = "targetTolLevel"

                class Advanced(Enum):
                    Acc = "maxAcc"
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    Jerk = "maxJerk"
                    ConfigOptObj = "nullspaceGradientScaling"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class MoveJ:
            PT_NAME = "MoveJ"
            PT_TYPE = "MOVEJ"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    Waypoints = "waypoints"
                    JntVelScale = "jntVelScale"
                    ZoneRadius = "zoneRadius"
                    TargetTolerLevel = "targetTolLevel"

                class Advanced(Enum):
                    EnableRelativeMove = "relativeToStart"
                    JntAccMultiplier = "jntAccMultiplier"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class MoveL:
            PT_NAME = "MoveL"
            PT_TYPE = "MOVEL"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    Waypoints = "waypoints"
                    Vel = "maxVel"
                    ZoneRadius = "zoneRadius"
                    TargetTolerLevel = "targetTolLevel"

                class Advanced(Enum):
                    Acc = "maxAcc"
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    Jerk = "maxJerk"
                    ConfigOptObj = "nullspaceGradientScaling"
                    EnableSixAxisJntCtrl = "enableSixJointAxesCtrl"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class MovePTP:
            PT_NAME = "MovePTP"
            PT_TYPE = "MOVEPTP"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    Waypoints = "waypoints"
                    JntVelScale = "jntVelScale"
                    ZoneRadius = "zoneRadius"
                    TargetTolerLevel = "targetTolLevel"

                class Advanced(Enum):
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    JntAccMultiplier = "jntAccMultiplier"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class MoveJTraj:
            PT_NAME = "MoveJTraj"
            PT_TYPE = "MOVEJTRAJ"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    TrajFileName = "fileName"
                    JntVelScale = "jntVelScale"
                    TargetTolerLevel = "targetTolLevel"

                class Advanced(Enum):
                    JntAccMultiplier = "jntAccMultiplier"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class Workflow:
        class Home:
            PT_NAME = "Home"
            PT_TYPE = "HOME"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    JntVelScale = "jntVelScale"

                class Advanced(Enum):
                    JntAccMultiplier = "jntAccMultiplier"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class Hold:
            PT_NAME = "Hold"
            PT_TYPE = "HOLD"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class End:
            PT_NAME = "End"
            PT_TYPE = "END"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class Stop:
            PT_NAME = "Stop"
            PT_TYPE = "STOP"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class Fault:
            PT_NAME = "Fault"
            PT_TYPE = "FAULT"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"

            class InputParams:
                class Basic(Enum):
                    ErrorMessage = "errorMessage"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class Subplan:
            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                LoopCnt = "loopCounter"

    class ZeroGravityFloating:
        class FloatingCartesian:
            PT_NAME = "FloatingCartesian"
            PT_TYPE = "CARTIMPEDANCEFLOATING"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                IdleTime = "idleTime"

            class InputParams:
                class Basic(Enum):
                    FloatingAxis = "cartFloatingAxis"
                    EnableElbowMotion = "enableJointFloating"
                    FloatingCoord = "floatingCoord"
                    DampingLevel = "resistanceLevel"

                class Advanced(Enum):
                    DiEnableFloating = "diEnableFloating"
                    ResponseTorque = "jointTorqueDeadBand"
                    InertiaScale = "inertiaScale"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class FloatingJoint:
            PT_NAME = "FloatingJoint"
            PT_TYPE = "JNTIMPEDANCEFLOATING"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                IdleTime = "idleTime"

            class InputParams:
                class Basic(Enum):
                    FloatingJoint = "jntFloatingAxis"
                    DampingLevel = "resistanceLevel"

                class Advanced(Enum):
                    ResponseTorque = "jointTorqueDeadBand"
                    DiEnableFloating = "diEnableFloating"
                    InertiaScale = "inertiaScale"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class SurfaceFinishing:
        class Polish:
            PT_NAME = "Polish"
            PT_TYPE = "POLISH"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    TrajFileName = "fileName"
                    TargetTolerLevel = "targetTolLevel"
                    ForceCoord = "forceCoord"
                    ForceAxis = "forceAxis"

                class Advanced(Enum):
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    ConfigOptObj = "nullspaceGradientScaling"
                    EnableForceAutoRot = "enableForceAutoRotation"
                    ForceRotAxis = "ForceRotationAxis"
                    EnableContactAngle = "enableContactAngle"
                    ContactAngle = "contactAngle"
                    ContactRotAxis = "rotAxis"
                    ContactRotRadius = "rotRadius"
                    EnableTrajOverlay = "enableTrajOverlay"
                    OverlaidTrajType = "overlaidTrajType"
                    Amplitude = "amplitude"
                    Pitch = "pitch"
                    OverlaidRotAngle = "rotAngle"
                    LineSpace = "lineSpace"
                    EnableTransLimit = "enableTransLimit"
                    MaxTransDisp = "maxTransDisp"
                    MinTransDisp = "minTransDisp"
                    EnableOrientLimit = "enableOrientLimit"
                    ToolRadius = "toolRadius"
                    MaxOrientAngle = "maxOrientAngle"
                    StiffScale = "stiffnessScaling"
                    EnableMaxWrench = "enableMaxContactWrench"
                    MaxContactWrench = "maxContactWrench"
                    MaxVelForceDir = "maxVelForceDir"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class Grind:
            PT_NAME = "Grind"
            PT_TYPE = "GRIND"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    TrajFileName = "fileName"
                    TargetTolerLevel = "targetTolLevel"
                    ForceCoord = "forceCoord"
                    ForceAxis = "forceAxis"

                class Advanced(Enum):
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    ConfigOptObj = "nullspaceGradientScaling"
                    EnableForceAutoRot = "enableForceAutoRotation"
                    ForceRotAxis = "ForceRotationAxis"
                    EnableContactAngle = "enableContactAngle"
                    ContactAngle = "contactAngle"
                    ContactRotAxis = "rotAxis"
                    ContactRotRadius = "rotRadius"
                    EnableTrajOverlay = "enableTrajOverlay"
                    OverlaidTrajType = "overlaidTrajType"
                    Amplitude = "amplitude"
                    Pitch = "pitch"
                    OverlaidRotAngle = "rotAngle"
                    LineSpace = "lineSpace"
                    EnableTransLimit = "enableTransLimit"
                    MaxTransDisp = "maxTransDisp"
                    MinTransDisp = "minTransDisp"
                    EnableOrientLimit = "enableOrientLimit"
                    ToolRadius = "toolRadius"
                    MaxOrientAngle = "maxOrientAngle"
                    StiffScale = "stiffnessScaling"
                    EnableMaxWrench = "enableMaxContactWrench"
                    MaxContactWrench = "maxContactWrench"
                    MaxVelForceDir = "maxVelForceDir"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class PolishECP:
            PT_NAME = "PolishECP"
            PT_TYPE = "POLISHECP"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    TrajFileName = "fileName"
                    ECPCoord = "ECPCoord"
                    TargetTolerLevel = "targetTolLevel"
                    ForceAxis = "forceAxis"

                class Advanced(Enum):
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    ConfigOptObj = "nullspaceGradientScaling"
                    EnableTrajOverlay = "enableTrajOverlay"
                    OverlaidTrajType = "overlaidTrajType"
                    Amplitude = "amplitude"
                    Pitch = "pitch"
                    OverlaidRotAngle = "rotAngle"
                    LineSpace = "lineSpace"
                    EnableTransLimit = "enableTransLimit"
                    MaxTransDisp = "maxTransDisp"
                    MinTransDisp = "minTransDisp"
                    StiffScale = "stiffnessScaling"
                    EnableMaxWrench = "enableMaxContactWrench"
                    MaxContactWrench = "maxContactWrench"
                    MaxVelForceDir = "maxVelForceDir"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class GrindECP:
            PT_NAME = "GrindECP"
            PT_TYPE = "GRINDECP"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    TrajFileName = "fileName"
                    ECPCoord = "ECPCoord"
                    TargetTolerLevel = "targetTolLevel"
                    ForceAxis = "forceAxis"

                class Advanced(Enum):
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    ConfigOptObj = "nullspaceGradientScaling"
                    EnableTrajOverlay = "enableTrajOverlay"
                    OverlaidTrajType = "overlaidTrajType"
                    Amplitude = "amplitude"
                    Pitch = "pitch"
                    OverlaidRotAngle = "rotAngle"
                    LineSpace = "lineSpace"
                    EnableTransLimit = "enableTransLimit"
                    MaxTransDisp = "maxTransDisp"
                    MinTransDisp = "minTransDisp"
                    StiffScale = "stiffnessScaling"
                    EnableMaxWrench = "enableMaxContactWrench"
                    MaxContactWrench = "maxContactWrench"
                    MaxVelForceDir = "maxVelForceDir"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class AdaptiveGrasping:
        class GraspComp:
            PT_NAME = "AdaptiveGrip"
            PT_TYPE = "ADAPTIVEGRIP"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                CurGripWidth = "curWidth"
                ReachGripForce = "reachedForce"
                ReachGripWidth = "reachedWidth"
                IsGripMoving = "isMoving"
                GripComplete = "graspComplete"

            class InputParams:
                class Basic(Enum):
                    GripperType = "gripperType"
                    GripVel = "gripSpeed"
                    GripWidth = "gripWidth"
                    GripForce = "maxGripForce"
                    ContactAxis = "contactDir"
                    ContactForce = "contactForce"
                    CompAxis = "compliantDir"
                    CompForce = "compliantForce"

                class Advanced(Enum):
                    MaxVelForceDir = "maxVelInForceDir"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class RehabilitationPhysiotherapy:
        class Massage:
            PT_NAME = "Massage"
            PT_TYPE = "MOVEHYBRID"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    TargetWrench = "goalWrench"
                    Waypoints = "waypoints"
                    Wrench = "wrench"
                    Vel = "maxVel"
                    ZoneRadius = "zoneRadius"
                    TargetTolerLevel = "targetTolLevel"
                    ForceCoord = "forceCoord"
                    ForceAxis = "forceAxis"
                    StiffScale = "stiffnessScaling"
                    EnableMaxWrench = "enableMaxContactWrench"
                    MaxContactWrench = "maxContactWrench"
                    EnableEntryPoint = "enableEntry"
                    MaxWrenchPause = "pauseAtMaxWrench"
                    MotionForceDecouple = "decoupleActuation"
                    WrenchFilterCutoff = "wrenchFilterCutoff"

                class Advanced(Enum):
                    Acc = "maxAcc"
                    Jerk = "maxJerk"
                    AngVel = "maxW"
                    EnableFixRefJntPos = "enablePreferJntPos"
                    RefJntPos = "preferJntPos"
                    ConfigOptObj = "nullspaceGradientScaling"
                    MaxVelForceDir = "maxVelForceDir"
                    LineSpace = "lineSpace"
                    Amplitude = "amplitude"
                    Pitch = "pitch"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class HighPerformanceVisionGuidance:
        class VSTeach:
            PT_NAME = "VisualServoTeach"
            PT_TYPE = "VISUALSERVOTEACH"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                TeachFinished = "teachFinished"

            class InputParams:
                class Basic(Enum):
                    ObjName = "objName"
                    ObjIndex = "objIdx"
                    CollectTimes = "sampleNum"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"
                TaughtFeaturePts2D = "taughtFeaturePts2D"
                TaughtAlignPts2D = "taughtMatchPts2D"
                TaughtFeaturePtsNoise = "taughtFeaturePtsNoise"
                TaughtFeaturePts3D = "taughtFeaturePts3D"
                TaughtAlignPts3D = "taughtMatchPts3D"
                TaughtObjPose = "taughtObjPose"
                TaughtAlignPose = "taughtMatchPose"

        class HPImageBasedVS:
            PT_NAME = "IBVS"
            PT_TYPE = "IBVS"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ObjAligned = "reachedTarget"

            class InputParams:
                class Basic(Enum):
                    ObjName = "objName"
                    ObjIndex = "objIdx"
                    TargetFeaturePts = "targetFeaturePoints"
                    TargetDepth = "targetDepth"
                    VsAxis = "vsAxis"
                    VelScale = "velScale"
                    MaxVel = "maxVel"
                    MaxAngVel = "maxRotVel"
                    ImageConvToler = "imgConvTol"
                    TargetConvTimes = "countTol"
                    TimeoutTime = "timeoutTime"

                class Advanced(Enum):
                    EnableObjAlign = "enableObjAlign"
                    AlignObjPts = "targetMatchObjPts"
                    OptVelScale = "optVelScale"
                    VisualDetectNoise = "AIDetectNoise"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class HPPoseBasedVS:
            PT_NAME = "PBVS"
            PT_TYPE = "PBVS"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ObjAligned = "reachedTarget"

            class InputParams:
                class Basic(Enum):
                    ObjName = "objName"
                    ObjIndex = "objIdx"
                    DetectObjPose = "enableObjPose"
                    TargetObjPose = "targetObjectPose"
                    VsCoord = "visualCoord"
                    VsAxis = "vsAxis"
                    VelScale = "velScale"
                    MaxVel = "maxVel"
                    MaxAcc = "maxAcc"
                    TimeoutTime = "timeoutTime"
                    VisualDelayTime = "compensateDelayTime"
                    PosConvToler = "posTol"
                    RotConvTimes = "oriTol"
                    TargetConvTimes = "countTol"

                class Advanced(Enum):
                    TargetFeaturePts = "targetFeaturePoints"
                    EnableObjAlign = "enableObjAlign"
                    AlignObjPts = "targetMatchFeaturePoints"
                    AlignObjPose = "targetMatchPose"
                    SuppressOvershoot = "suppressOvershoot"
                    DynamicObjTrack = "dynamicObjTrack"
                    VisDetectNoiseLevel = "visualDetectNoiseLevel"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class HPOffsetServo:
            PT_NAME = "OBVS"
            PT_TYPE = "OBVS"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ObjAligned = "reachedTarget"

            class InputParams:
                class Basic(Enum):
                    ObjName = "objName"
                    ObjIndex = "objIdx"
                    Target = "target"
                    VsCoord = "vsCoord"
                    VsAxis = "vsAxis"
                    VelScale = "velScale"
                    MaxVel = "maxVel"
                    MaxAcc = "maxAcc"
                    TimeoutTime = "timeoutTime"
                    VisualDelayTime = "visualDelayTime"
                    PosConvToler = "posConvToler"
                    RotConvTimes = "rotConvToler"
                    TargetConvTimes = "countTol"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class Showcase:
        class BalanceBall:
            PT_NAME = "BallBalance"
            PT_TYPE = "MPCBALLBALANCING"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"

            class InputParams:
                class Basic(Enum):
                    BallWeight = "ballWeight"
                    BallFricCoeff = "ballFrictionCoeff"
                    PattenType = "trajType"
                    COPOffsetX = "COPOffsetX"
                    COPOffsetY = "COPOffsetY"

                class Advanced(Enum):
                    PattenSizeScale = "pathScale"
                    FreScale = "freScale"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class BalanceGlasses:
            PT_NAME = "BalanceGlasses"
            PT_TYPE = "BALANCEGLASSES"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                ReachedTarget = "reachedTarget"
                WaypointIndex = "waypointIndex"

            class InputParams:
                class Basic(Enum):
                    Target = "target"
                    Duration = "duration"
                    Waypoints = "waypoints"
                    TargetTolerLevel = "targetTolLevel"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

    class Synchronization:
        class SyncStart:
            PT_NAME = "SyncStart"
            PT_TYPE = "SYNCSTART"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"
                WorkpieceDetected = "workpieceDetected"

            class InputParams:
                class Basic(Enum):
                    SyncDevice = "syncDevice"
                    TeachCoord = "teachCoord"

                class Advanced(Enum):
                    TrackVel = "maxTrackVel"
                    TrackAcc = "maxTrackAcc"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class SyncHold:
            PT_NAME = "SyncHold"
            PT_TYPE = "SYNCHOLD"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"

        class SyncEnd:
            PT_NAME = "SyncEnd"
            PT_TYPE = "SYNCEND"

            class State(Enum):
                Terminated = "terminated"
                TimePeriod = "timePeriod"

            class InputParams:
                class Basic(Enum):
                    SyncDevice = "syncDevice"

            class OutputParams(Enum):
                TcpPoseOut = "tcpPoseOut"


class TrajFrameValueEnum(Enum):
    Start = "START"
    Goal = "GOAL"
    PreviousWayPoint = "PREVIOUSWAYPOINT"


class WorldFrameValueEnum(Enum):
    World_Origin = "WORLD_ORIGIN"


class TcpFrameValueEnum(Enum):
    Start = "START"
    Online = "Online"


class GripperNameEnum(Enum):
    GripperDahuan = "GripperDahuan"
    GripperDahuanModbus = "GripperDahuanModbus"
    Flexiv_GN01 = "Flexiv-GN01"
    GripperFlexivModbus = "GripperFlexivModbus"
    Robotiq_2F_85 = "Robotiq-2F-85"
    Robotiq_Hand_E = "Robotiq-Hand-E"


class DeviceNameEnum(Enum):
    GripperDahuan = "GripperDahuan"
    GripperDahuanModbus = "GripperDahuanModbus"
    Flexiv_GN01 = "Flexiv-GN01"
    GripperFlexivModbus = "GripperFlexivModbus"
    Robotiq_2F_85 = "Robotiq-2F-85"
    Robotiq_Hand_E = "Robotiq-Hand-E"
    IndustrialCam = "IndustrialCam"
    Mirka_AIROS_550CV = "Mirka-AIROS-550CV"
    Conveyor_SerialPort_1 = "Conveyor-SerialPort-1"
    Conveyor_SerialPort_2 = "Conveyor-SerialPort-2"
    Conveyor_SerialPort_3 = "Conveyor-SerialPort-3"
    Conveyor_RemoteHost_1 = "Conveyor-RemoteHost-1"
    Conveyor_RemoteHost_2 = "Conveyor-RemoteHost-2"
    Conveyor_RemoteHost_3 = "Conveyor-RemoteHost-3"
    Conveyor_VisionTrack_1 = "Conveyor-VisionTrack-1"
    Conveyor_VisionTrack_2 = "Conveyor-VisionTrack-2"
    Conveyor_VisionTrack_3 = "Conveyor-VisionTrack-3"
    Conveyor_ModbusTCP_1 = "Conveyor-ModbusTCP-1"
    Conveyor_ModbusTCP_2 = "Conveyor-ModbusTCP-2"
    Conveyor_ModbusTCP_3 = "Conveyor-ModbusTCP-3"