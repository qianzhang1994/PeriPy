#pragma OPENCL EXTENSION cl_khr_fp64 : enable


double euclid(__global const double* r, int i, int j) {
    int il = i*3;
    int jl = j*3;

    double dx = r[jl] - r[il];
    double dy = r[jl+1] - r[il+1];
    double dz = r[jl+2] - r[il+2];

    return sqrt(dx*dx + dy*dy + dz*dz);
}


__kernel void neighbourhood(__global const double* r, double threshold,
                            __global bool* nhood) {
    int i = get_global_id(0);
    int j = get_global_id(1);
    int n = get_global_size(1);

    int index = i*n + j;

    if (i == j) {
        nhood[index] = false;
    } else {
        nhood[i*n + j] = euclid(r, i, j) < threshold;
    }
}


__kernel void dist(__global const double* r, __global const bool* nhood,
                   __global double* d) {
    int i = get_global_id(0);
    int j = get_global_id(1);
    int n = get_global_size(1);

    int index = i*n + j;
    if (nhood[index]) {
        d[index] = euclid(r, i, j);
    }
}


__kernel void strain(__global const double* r, __global const double* d0,
                     __global const bool* nhood, __global double* strain) {
    int i = get_global_id(0);
    int j = get_global_id(1);
    int n = get_global_size(1);

    int index = i*n +j;

    if (nhood[index]) {
        double l0 = d0[index];
        if (l0 == 0.) {
            strain[index] = 0.;
        } else {
            double l = euclid(r, i, j);
            strain[index] = (l - l0) / l0;
        }
    }
}


__kernel void break_bonds(__global const double* strain, double critical_strain,
                          __global bool* nhood) {
    int i = get_global_id(0);
    int j = get_global_id(1);
    int n = get_global_size(1);

    int index = i*n +j;

    if (nhood[index]) {
        if (fabs(strain[index]) > critical_strain) {
            nhood[index] = false;
        }
    }
}


__kernel void damage(__global const int* n_neigh, __global const int* family,
                     __global double* damage){
    int i = get_global_id(0);

    int ifamily = family[i];
    damage[i] = (double)(ifamily - n_neigh[i])/ifamily;
}


/* Force
 * global size (nnodes, nnodes, 3) local size (group_size, 1, 1)
 * each work item calculates a force for pair global_size(0), global_size(1) in dimension global_size(2)
 *   - strain(i,j) / euclidean_distance(i,j)
 *   - *= volume(i)
 *   - *= bond_stiffness
 *   - *= distance_in_dimension_k(i,j)
 * reduction sum over axis0 leaving a (npartials, nnodes, 3) array, finish sum on host
 */
// __kernel void force(__global const double* strain, __global const double* dist,
//                     __global const double* volume, float bond_stiffness
//                     __local float* b, __global double* partials) {
//     int gid0 = get_global_id(0);
//     int gid1 = get_global_id(1);
//     int gsize1 = get_global_size(1);

//     int lid = get_local_id(0);
//     int lsize = get_local_size(0);
//     int wg = get_group_id(0);

//     int index = gid0*gsize1 + gid1;
//     float norm_force = strain[

//     // Copy to local memory
//     b[lid] = a[gid0*gsize1 + gid1];
//     barrier(CLK_LOCAL_MEM_FENCE);

//     // Reduction within work group, sum is left in b[0]
//     for (int stride=lsize>>1; stride>0; stride>>=1) {
//         if (lid < stride) {
//             b[lid] += b[lid+stride];
//         }
//         barrier(CLK_LOCAL_MEM_FENCE);
//     }

//     // Local thread 0 copies its work group sum to the result array
//     if (lid == 0) {
//         // row is wg
//         // col is gid1
//         partials[wg*gsize1 + gid1] = b[0];
//     }
// }
