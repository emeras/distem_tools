#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <mpi.h>

int main(int argc, char ** argv)
{
  int i, rank, out, nb_procs = 0;
  int iter = 100;
  int* array = 0;
  double t_loop_start, t_loop_stop;
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  if (rank == 0)
  {
    MPI_Comm_size(MPI_COMM_WORLD, &nb_procs);
    //fprintf(stderr, "%d cores\n", nb_procs);
    printf("# %d cores\n", nb_procs);
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
  MPI_Finalize();
  if (rank == 0) {
    printf("%f\n", t_loop_stop-t_loop_start);
  }
  return(0);
}

