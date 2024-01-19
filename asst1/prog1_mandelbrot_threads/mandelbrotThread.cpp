#include <stdio.h>
#include <thread>
#include <iostream>
#include "CycleTimer.h"

typedef struct {
    float x0, x1;
    float y0, y1;
    unsigned int width;
    unsigned int height;
    int maxIterations;
    int startRow;
    int numRows;
    int* output;
    int threadId;
    int numThreads;
} WorkerArgs;


extern void mandelbrotSerial(
    float x0, float y0, float x1, float y1,
    int width, int height,
    int startRow, int numRows,
    int maxIterations,
    int output[]);


//
// workerThreadStart --
//
// Thread entrypoint.
void workerThreadStart(WorkerArgs * const args) {

    // TODO FOR CS149 STUDENTS: Implement the body of the worker
    // thread here. Each thread should make a call to mandelbrotSerial()
    // to compute a part of the output image.  For example, in a
    // program that uses two threads, thread 0 could compute the top
    // half of the image and thread 1 could compute the bottom half.

    // each thread has a block to work.
    double startTime = CycleTimer::currentSeconds();
    mandelbrotSerial(args->x0,args->y0,args->x1,args->y1,args->width,args->height,args->startRow,args->numRows,args->maxIterations,args->output);
    double endTime = CycleTimer::currentSeconds();
    double time_per_thread = endTime - startTime;
    // std::cout<<"Thread "<<args->threadId<<" spends "<<time_per_thread*1000<<" ms to compute"<<std::endl;
}

//Map work to each thread with block
// MandelbrotThread
//
// Multi-threaded implementation of mandelbrot set image generation.
// Threads of execution are created by spawning std::threads.
void mandelbrotThread(
    int numThreads,
    float x0, float y0, float x1, float y1,
    int width, int height,
    int maxIterations, int output[])
{
    static constexpr int MAX_THREADS = 64;

    if (numThreads > MAX_THREADS)
    {
        fprintf(stderr, "Error: Max allowed threads is %d\n", MAX_THREADS);
        exit(1);
    }

    // Creates thread objects that do not yet represent a thread.
    std::thread workers[MAX_THREADS];
    WorkerArgs args[MAX_THREADS];
    int avg_row = height/numThreads;
    int rem_row = height%numThreads;

    for (int i=0; i<numThreads; i++) {
      
        // TODO FOR CS149 STUDENTS: You may or may not wish to modify
        // the per-thread arguments here.  The code below copies the
        // same arguments for each thread
        args[i].x0 = x0;
        args[i].y0 = y0;
        args[i].x1 = x1;
        args[i].y1 = y1;
        args[i].width = width;
        args[i].height = height;
        args[i].maxIterations = maxIterations;
        args[i].numThreads = numThreads;
        args[i].output = output;
        args[i].startRow = i*avg_row;
        args[i].numRows = avg_row;
        if(i==numThreads-1) args[i].numRows+=rem_row;
        args[i].threadId = i;
    }

    // Spawn the worker threads.  Note that only numThreads-1 std::threads
    // are created and the main application thread is used as a worker
    // as well.
    for (int i=1; i<numThreads; i++) {
        workers[i] = std::thread(workerThreadStart, &args[i]);
    }
    
    workerThreadStart(&args[0]);

    // join worker threads
    for (int i=1; i<numThreads; i++) {
        workers[i].join();
    }
}

void mandelbrotThread_v2(
    int numThreads,
    float x0, float y0, float x1, float y1,
    int width, int height,
    int maxIterations, int output[])
{
    static constexpr int MAX_THREADS = 64;

    if (numThreads > MAX_THREADS)
    {
        fprintf(stderr, "Error: Max allowed threads is %d\n", MAX_THREADS);
        exit(1);
    }

    // Creates thread objects that do not yet represent a thread.
    std::thread workers[MAX_THREADS];
    WorkerArgs args[MAX_THREADS];
    int avg_row = height/numThreads;
    int rem_row = height%numThreads;

    for (int i=0; i<numThreads; i++) {
        int local_row = avg_row;
        if(i==numThreads-1) local_row+=rem_row;
        int local_start = i*avg_row;
        for(int j=0;j<numThreads;++j){
            int th_avg_row = local_row/numThreads;
            int th_rem_row = local_row%numThreads;
            int index = i*numThreads+j;
            args[index].x0 = x0;
            args[index].y0 = y0;
            args[index].x1 = x1;
            args[index].y1 = y1;
            args[index].width = width;
            args[index].height = height;
            args[index].maxIterations = maxIterations;
            args[index].numThreads = numThreads;
            args[index].output = output;
            args[index].startRow = local_start+j*th_avg_row;
            args[index].numRows = th_avg_row;
            if(j==numThreads-1) args[index].numRows+=th_rem_row;
            args[index].threadId = index;
        }
    }

    // Spawn the worker threads.  Note that only numThreads-1 std::threads
    // are created and the main application thread is used as a worker
    // as well.
    for (int i=1; i<numThreads*numThreads; i++) {
        workers[i] = std::thread(workerThreadStart, &args[i]);
    }
    
    workerThreadStart(&args[0]);

    // join worker threads
    for (int i=1; i<numThreads*numThreads; i++) {
        workers[i].join();
    }
}


