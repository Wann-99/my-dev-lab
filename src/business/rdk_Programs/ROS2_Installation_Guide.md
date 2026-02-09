# Flexiv ROS 2 Installation Guide

This guide covers the installation and setup of ROS 2 for Flexiv robots. It is based on the official [flexiv_ros2](https://github.com/flexivrobotics/flexiv_ros2) documentation.

## Prerequisites
- **Operating System**: 
  - Ubuntu 22.04 LTS (Recommended for ROS 2 Humble)
  - Ubuntu 20.04 LTS (for ROS 2 Foxy)
- **ROS 2 Distribution**: 
  - **Humble Hawksbill** (Recommended)
  - Foxy Fitzroy

> **Note**: While you can install ROS 2 on Windows, the Flexiv driver and RDK are primarily optimized and tested on Linux (Ubuntu). Using WSL2 (Windows Subsystem for Linux) with Ubuntu 22.04 is a viable option if you are on Windows.

## Step 1: Install ROS 2
Follow the official ROS 2 installation guide for your platform.

For **Ubuntu 22.04 (Humble)**:
[ROS 2 Humble Installation Guide](https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debians.html)

## Step 2: Install Build Tools and Dependencies
Install `colcon` and other necessary ROS 2 packages.

```bash
sudo apt install -y \
python3-colcon-common-extensions \
python3-rosdep2 \
libeigen3-dev \
ros-humble-xacro \
ros-humble-tinyxml2-vendor \
ros-humble-ros2-control \
ros-humble-realtime-tools \
ros-humble-control-toolbox \
ros-humble-moveit \
ros-humble-ros2-controllers \
ros-humble-test-msgs \
ros-humble-joint-state-publisher \
ros-humble-joint-state-publisher-gui \
ros-humble-robot-state-publisher \
ros-humble-rviz2
```

## Step 3: Setup Workspace
Create a workspace and clone the Flexiv ROS 2 repository:

```bash
mkdir -p ~/flexiv_ros2_ws/src
cd ~/flexiv_ros2_ws/src
git clone https://github.com/flexivrobotics/flexiv_ros2.git
cd flexiv_ros2/
git submodule update --init --recursive
```

## Step 4: Install Dependencies (rosdep)
Install dependencies using `rosdep`:

```bash
cd ~/flexiv_ros2_ws
rosdep update
rosdep install --from-paths src --ignore-src --rosdistro humble -r -y
```

## Step 5: Install Flexiv RDK
The ROS 2 driver requires the `flexiv_rdk` C++ library. You can compile it from the submodule included in the repository.

1. **Install RDK Dependencies**:
   (You can choose a custom installation path, e.g., `~/rdk_install`)
   ```bash
   cd ~/flexiv_ros2_ws/src/flexiv_ros2/flexiv_hardware/rdk/thirdparty
   bash build_and_install_dependencies.sh ~/rdk_install
   ```

2. **Compile and Install RDK**:
   ```bash
   cd ~/flexiv_ros2_ws/src/flexiv_ros2/flexiv_hardware/rdk
   mkdir build && cd build
   cmake .. -DCMAKE_INSTALL_PREFIX=~/rdk_install
   cmake --build . --target install --config Release
   ```

## Step 6: Build the Workspace
Build the ROS 2 workspace, pointing to the RDK installation:

```bash
cd ~/flexiv_ros2_ws
source /opt/ros/humble/setup.bash
colcon build --symlink-install --cmake-args -DCMAKE_PREFIX_PATH=~/rdk_install
source install/setup.bash
```

> **Tip**: Add the source commands to your `~/.bashrc` to avoid running them in every new terminal:
> ```bash
> echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
> echo "source ~/flexiv_ros2_ws/install/setup.bash" >> ~/.bashrc
> ```

## Usage

### 1. Bringup Robot (Real Hardware)
To start the robot driver and RViz with a real robot:

```bash
# Replace [robot_sn] with your robot's serial number (e.g., Rizon4s-123456)
ros2 launch flexiv_bringup rizon.launch.py robot_sn:=[robot_sn] rizon_type:=Rizon4
```

### 2. Fake Hardware (Simulation)
If you don't have a real robot connected, you can use the fake hardware mode:

```bash
ros2 launch flexiv_bringup rizon.launch.py robot_sn:=Rizon4-123456 use_fake_hardware:=true
```

## Useful Links
- [Flexiv ROS 2 GitHub Repository](https://github.com/flexivrobotics/flexiv_ros2)
- [Flexiv RDK Documentation](https://www.flexiv.com/software/rdk)
