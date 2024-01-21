#include <stdio.h>

#include <cuda.h>
#include <cuda_runtime.h>

#include <driver_functions.h>

#include <thrust/scan.h>
#include <thrust/device_ptr.h>
#include <thrust/device_malloc.h>
#include <thrust/device_free.h>
#include <thrust/functional.h>
#include <thrust/transform.h>

#include "CycleTimer.h"

#define THREADS_PER_BLOCK 256


// helper function to round an integer up to the next power of 2
static inline int nextPow2(int n) {
    n--;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    n++;
    return n;
}

// exclusive_scan --
//
// Implementation of an exclusive scan on global memory array `input`,
// with results placed in global memory `result`.
//
// N is the logical size of the input and output arrays, however
// students can assume that both the start and result arrays we
// allocated with next power-of-two sizes as described by the comments
// in cudaScan().  This is helpful, since your parallel scan
// will likely write to memory locations beyond N, but of course not
// greater than N rounded up to the next power of 2.
//
// Also, as per the comments in cudaScan(), you can implement an
// "in-place" scan, since the timing harness makes a copy of input and
// places it in result

__global__ void hs_scan_kernel(int* input, int N, int k) {
    // get the global thread index
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    // check the thread index is within the array bounds
    if (i < N) {
        // get the distance to the previous element
        int offset = 1 << k;
        // check the previous element exists
        if (i >= offset) {
            // perform the scan operation
            input[i] = input[i] + input[i - offset];
        }
    }
}

__global__ void shift_right_kernel(int* result, int N, int M) {
    // get the thread index
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    // check the boundary
    if (i < M) {
        // if the index is within N, copy the previous element
        if (i < N) {
            result[i] = result[i-1];
        }
        // if the index is equal to 0, set it to 0
        else if (i == 0) {
            result[i] = 0;
        }
        // otherwise, do nothing
    }
}

void exclusive_scan(int* input, int N, int* result)
{   
    // printf("start exclusive scan");s
    // copy the input array to the result array
    cudaMemcpy(result, input, N * sizeof(int), cudaMemcpyDeviceToDevice);
    // get the next power of 2 of N
    int M = nextPow2(N);
    // set the block and grid dimensions
    int blockSize = 256;
    int gridSize = (M + blockSize - 1) / blockSize;
    // loop over the log2(M) steps
    for (int k = 0; k <= log2(M); k++) {
        // call the scan kernel
        hs_scan_kernel<<<gridSize, blockSize>>>(result, N, k);
        // synchronize the device
        cudaDeviceSynchronize();
    }
    // call the shift right kernel with the same grid and block dimensions
    shift_right_kernel<<<gridSize, blockSize>>>(result, N, M);
    // synchronize the device
    cudaDeviceSynchronize();
    // copy the result array back to the host memory
    // cudaMemcpy(result+4, result, (N-1) * sizeof(int), cudaMemcpyDeviceToDevice);
}

//
// cudaScan --
//
// This function is a timing wrapper around the student's
// implementation of scan - it copies the input to the GPU
// and times the invocation of the exclusive_scan() function
// above. Students should not modify it.
double cudaScan(int* inarray, int* end, int* resultarray)
{
    int* device_result;
    int* device_input;
    int N = end - inarray;  

    // This code rounds the arrays provided to exclusive_scan up
    // to a power of 2, but elements after the end of the original
    // input are left uninitialized and not checked for correctness.
    //
    // Student implementations of exclusive_scan may assume an array's
    // allocated length is a power of 2 for simplicity. This will
    // result in extra work on non-power-of-2 inputs, but it's worth
    // the simplicity of a power of two only solution.

    int rounded_length = nextPow2(end - inarray);
    // printf("the rounded_lenth is: %d",rounded_length);
    cudaMalloc((void **)&device_result, sizeof(int) * rounded_length);
    cudaMalloc((void **)&device_input, sizeof(int) * rounded_length);

    // For convenience, both the input and output vectors on the
    // device are initialized to the input values. This means that
    // students are free to implement an in-place scan on the result
    // vector if desired.  If you do this, you will need to keep this
    // in mind when calling exclusive_scan from find_repeats.
    cudaMemcpy(device_input, inarray, (end - inarray) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(device_result, inarray, (end - inarray) * sizeof(int), cudaMemcpyHostToDevice);

    double startTime = CycleTimer::currentSeconds();

    exclusive_scan(device_input, N, device_result);

    // Wait for completion
    cudaDeviceSynchronize();
    double endTime = CycleTimer::currentSeconds();
       
    cudaMemcpy(resultarray, device_result, (end - inarray) * sizeof(int), cudaMemcpyDeviceToHost);

    double overallDuration = endTime - startTime;
    return overallDuration; 
}


// cudaScanThrust --
//
// Wrapper around the Thrust library's exclusive scan function
// As above in cudaScan(), this function copies the input to the GPU
// and times only the execution of the scan itself.
//
// Students are not expected to produce implementations that achieve
// performance that is competition to the Thrust version, but it is fun to try.
double cudaScanThrust(int* inarray, int* end, int* resultarray) {

    int length = end - inarray;
    thrust::device_ptr<int> d_input = thrust::device_malloc<int>(length);
    thrust::device_ptr<int> d_output = thrust::device_malloc<int>(length);
    
    cudaMemcpy(d_input.get(), inarray, length * sizeof(int), cudaMemcpyHostToDevice);

    double startTime = CycleTimer::currentSeconds();

    thrust::exclusive_scan(d_input, d_input + length, d_output);

    cudaDeviceSynchronize();
    double endTime = CycleTimer::currentSeconds();
   
    cudaMemcpy(resultarray, d_output.get(), length * sizeof(int), cudaMemcpyDeviceToHost);

    thrust::device_free(d_input);
    thrust::device_free(d_output);

    double overallDuration = endTime - startTime;
    return overallDuration; 
}

// A kernel function to convert the input array to a flag array
__global__ void flag_kernel(int* device_input, int* device_flag, int length) {
    // Get the thread index
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    // Check the boundary
    if (index < length - 1) {
        // Compare the current element with the next element
        if (device_input[index] == device_input[index + 1]) {
            // Set the flag to 1 if they are equal
            device_flag[index] = 1;
        } else {
            // Set the flag to 0 otherwise
            device_flag[index] = 0;
        }
    }
    // The last element has no next element, so set the flag to 0
    if (index == length - 1) {
        device_flag[index] = 0;
    }
    // Synchronize the threads
    __syncthreads();
}

// A kernel function to convert the scan array to the output array
__global__ void output_kernel(int* device_scan, int* device_output, int length) {
    // Get the thread index
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    // Check the boundary
    if (index < length) {
        // Use a shared variable to store the current position of the output array
        __shared__ int pos;
        // Initialize the position to 0 in the first thread
        if (threadIdx.x == 0) {
            pos = 0;
        }
        // Synchronize the threads
        __syncthreads();
        // Check if the current element is a flag
        if (device_scan[index] > device_scan[index - 1]) {
            // Get the current position of the output array atomically
            int p = atomicAdd(&pos, 1);
            // Store the index of the flag to the output array
            device_output[p] = index;
        }
        // Synchronize the threads
        __syncthreads();
    }
}

// A function to find the repeats using exclusive_scan
int find_repeats(int* device_input, int length, int* device_output) {
    // Allocate memory for the flag array and the scan array
    int* device_flag;
    int* device_scan;
    cudaMalloc(&device_flag, length * sizeof(int));
    cudaMalloc(&device_scan, length * sizeof(int));
    // Define the block size and the grid size
    int block_size = 256;
    int grid_size = (length + block_size - 1) / block_size;
    // Launch the flag kernel
    flag_kernel<<<grid_size, block_size>>>(device_input, device_flag, length);
    // Launch the exclusive_scan function
    exclusive_scan(device_flag, length, device_scan);
    // Launch the output kernel
    output_kernel<<<grid_size, block_size>>>(device_scan, device_output, length);
    // Copy the last element of the scan array to the host memory
    int result;
    cudaMemcpy(&result, device_scan + length - 1, sizeof(int), cudaMemcpyDeviceToHost);
    // Free the allocated memory
    cudaFree(device_flag);
    cudaFree(device_scan);
    // Return the number of pairs found
    return result;
}

//
// cudaFindRepeats --
//
// Timing wrapper around find_repeats. You should not modify this function.
double cudaFindRepeats(int *input, int length, int *output, int *output_length) {

    int *device_input;
    int *device_output;
    int rounded_length = nextPow2(length);
    
    cudaMalloc((void **)&device_input, rounded_length * sizeof(int));
    cudaMalloc((void **)&device_output, rounded_length * sizeof(int));
    cudaMemcpy(device_input, input, length * sizeof(int), cudaMemcpyHostToDevice);

    cudaDeviceSynchronize();
    double startTime = CycleTimer::currentSeconds();
    
    int result = find_repeats(device_input, length, device_output);

    cudaDeviceSynchronize();
    double endTime = CycleTimer::currentSeconds();

    // set output count and results array
    *output_length = result;
    cudaMemcpy(output, device_output, length * sizeof(int), cudaMemcpyDeviceToHost);
    // due to GPU's paralle computing, the result needs to be sorted
    std::sort(output,output+length);
    cudaFree(device_input);
    cudaFree(device_output);

    float duration = endTime - startTime; 
    return duration;
}



void printCudaInfo()
{
    int deviceCount = 0;
    cudaError_t err = cudaGetDeviceCount(&deviceCount);

    printf("---------------------------------------------------------\n");
    printf("Found %d CUDA devices\n", deviceCount);

    for (int i=0; i<deviceCount; i++)
    {
        cudaDeviceProp deviceProps;
        cudaGetDeviceProperties(&deviceProps, i);
        printf("Device %d: %s\n", i, deviceProps.name);
        printf("   SMs:        %d\n", deviceProps.multiProcessorCount);
        printf("   Global mem: %.0f MB\n",
               static_cast<float>(deviceProps.totalGlobalMem) / (1024 * 1024));
        printf("   CUDA Cap:   %d.%d\n", deviceProps.major, deviceProps.minor);
    }
    printf("---------------------------------------------------------\n"); 
}
