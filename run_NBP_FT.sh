#!/bin/bash

apt-get install -y fortran77-compiler gfortran gfortran-multilib

for i in {1..20000}; do
  taskset -c 0 ~jemeras/public/distem/distem_experiments/NPB3.3/NPB3.3-SER/bin/ft.A
done

