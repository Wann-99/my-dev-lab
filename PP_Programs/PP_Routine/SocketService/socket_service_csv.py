import socket
import time
import threading
import argparse
from datetime import datetime
import csv
import os


def FileName():  # Data sheet file name
    # fileName = str(datetime.now().year)+"-"+datetime.now().month+"-"+datetime.now().day+"-"+datetime.now().hour+"-"+datetime.now().minute+".csv"
    fileName = datetime.now().strftime("%Y-%m-%d-%H:%M:%S") + ".csv"
    return fileName


fileName = FileName()


def Writer2CVSHeader(fileName):  # Creat sheet header
    with open(fileName, 'a+', newline='') as csvfile:
        dataWriter = csv.writer(csvfile, delimiter=',')
        dataWriter.writerow(
            ["Index", "Time", "Pose_X", "Pose_Y", "Pose_Z", "Pose_Rx", "Pose_Ry", "Pose_Rz", "Force_X", "Force_Y",
             "Force_Z", "Force_Mx", "Force_My", "Force_Mz"])


def Write2CSV(fileName, value1, value3):  # creat csv file
    if os.path.exists(fileName):  # Writer data
        with open(fileName, 'a+', newline='') as csvfile:
            dataWriter = csv.writer(csvfile, delimiter=',')
            dataWriter.writerow(
                [value3, datetime.now().strftime("%Y-%m-%d-%H:%M:%S.%f")[:-3], value1[0], value1[1], value1[2],
                 value1[3], value1[4], value1[5], value1[-6], value1[-5], value1[-4], value1[-3], value1[-2],
                 value1[-1]])


def tcplick(sock, addr):
    print('Accepting %s:%s' % addr)
    print("nnFile Name is :", fileName)
    print("Collecting data ...... press ctrl+c to stop")
    index = 0
    elements = []
    while True:
        data = sock.recv(1024)
        decoded_data = data.decode('utf_8')
        # print(decoded_data)
        lines = decoded_data.splitlines()
        for line in lines:
            if index == 0:
                print(index, line)
                index = index + 1
                continue  # discard Hi Flexiv
            else:
                elements = line.split(",")
                print(elements)
                # print(index)
                Write2CSV(fileName, elements, index)
                index = index + 1

        if not data or decoded_data == 'exit':
            break

    sock.close()
    print('Close Connection %s:%s' % addr)


if __name__ == "__main__":
    if os.path.exists(fileName) == False:  # Writer sheet header
        Writer2CVSHeader(fileName)
    else:
        print("Can't creat csv file...")
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(('192.168.2.201', 20000))
    server.listen(5)
    print('Wait for connection...')
    while True:
        sock, addr = server.accept()
        new_thread = threading.Thread(target=tcplick, args=(sock, addr))
        new_thread.start()