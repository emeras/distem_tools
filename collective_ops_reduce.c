#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <mpi.h>

int main(int argc, char ** argv)
{
  int i, rank, out, nb_procs = 0;
  int iter = 1000;
  int* array = 0;
  double t_loop_start, t_loop_stop, min_start, max_stop;

  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  if (rank == 0)
  {
    MPI_Comm_size(MPI_COMM_WORLD, &nb_procs);
    printf("Running on %d procs\n", nb_procs);
    array = (int*)calloc(nb_procs, sizeof(int));
    for (i = 0; i < nb_procs; i++)
      array[i] = nb_procs - i - 1;
  }
  t_loop_start = MPI_Wtime();
  for (i = 0; i < iter; i++)
  {
    MPI_Bcast(&nb_procs, 1, MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Scatter(array, 1, MPI_INT, &out, 1, MPI_INT, 0, MPI_COMM_WORLD);
    if (rank == 0)
      memset(array, 0, nb_procs);
    MPI_Gather(&out, 1, MPI_INT, array, 1, MPI_INT, 0, MPI_COMM_WORLD);
  }
  t_loop_stop = MPI_Wtime();
  
  MPI_Reduce(&t_loop_start, &min_start, 1, MPI_DOUBLE, MPI_MIN, 0, MPI_COMM_WORLD);
  MPI_Reduce(&t_loop_stop, &max_stop, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    
  MPI_Finalize();
  if (rank == 0) {
    printf("Time in the loop: %f\n", t_loop_stop-t_loop_start); 
    fflush(stdout);
  }
  return(0);
}
