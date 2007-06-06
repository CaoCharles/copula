/*#################################################################
##   Copula R package by Jun Yan Copyright (C) 2007
##
##   Multivariate independence test  based on the empirical copula
##   Copyright (C) 2007 Ivan Kojadinovic <ivan.kojadinovic@univ-nantes.fr>
##
##   This program is free software; you can redistribute it and/or modify
##   it under the terms of the GNU General Public License as published by
##   the Free Software Foundation; either version 2 of the License, or
##   (at your option) any later version.
##
##   This program is distributed in the hope that it will be useful,
##   but WITHOUT ANY WARRANTY; without even the implied warranty of
##   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##   GNU General Public License for more details.
##
##   You should have received a copy of the GNU General Public License along
##   with this program; if not, write to the Free Software Foundation, Inc.,
##   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
##
#################################################################*/

/*****************************************************************************

  Multivariate independence test  based on the empirical 
  copula process as proposed by Christian Genest and Bruno 
  R�millard (2004), Test 13:2, pages 335-369.

  Ivan Kojadinovic, May 2007

*****************************************************************************/

#include <R.h>
#include <Rmath.h>
#include "set.utils.h"

/*****************************************************************************

  Computation of the Cramer-von Mises statistic used in the independence
  test of Genest and Remillard based on the empirical copula for a
  subset A of {1,...,p}
  
******************************************************************************/

inline double Dn(int n, int s, int t)
{
  return (2.0 * n + 1.0) / (6.0 * n) + (s * (s - 1.0) + t * (t - 1.0)) / (2.0 * n * (n + 1.0)) 
    - fmax2(s,t) / (n + 1.0);
}

inline double empirical_copula_subset(int n, int p, int *R, int A)
{
  int i,j,k;
  double TA = 0.0, prod;
  i=0;k=0;
  for (i=0;i<n;i++)
    for (k=0;k<n;k++) {
      prod = 1.0;
      for (j=0;j<p;j++)
	if (1<<j & A)
	  prod *= Dn(n, R[i + n*j], R[k + n*j]);
      TA += prod;
    }
  return TA/n;
}

/*****************************************************************************

  Simulate the distribution of TA, up to subsets of cardinality p
  n: sample size
  N: number of repetitions
  p: dimension of data
  m: max. card. of A
  TA0: values of TA under independence (N repetitions)
  subset: subsets of {1,...,p} in binary notation (int) whose card. is 
  between 2 and m in "natural" order
  subset_char: similar, for printing
  
******************************************************************************/

void simulate_empirical_copula(int *n, int *N, int *p, int *m, double *TA0, 
			       int *subset, char **subset_char)
{
  int i, j, k, sb = (int)sum_binom(*p,*m);
  double *u = (double *)R_alloc((*n) * (*p), sizeof(double));
  int *R = (int *)R_alloc((*n) * (*p), sizeof(int));
  
  /* partial power set in "natural" order */ 
  k_power_set(p, m, subset);

  /* convert partial power set to char for printing */
  k_power_set_char(p,m, subset, subset_char);
  
  /* Simulate the distribution of TA under independence */
  GetRNGstate();
  
  /* N repetitions */
  for (k=0;k<*N;k++) { 
    
    /* generate data */
    for (j=0;j<*p;j++) {
      for (i=0;i<*n;i++) {  
	u[i + (*n) * j] = unif_rand();
	R[i + (*n) * j] = i+1;
      }
      rsort_with_index (u + (*n) * j, R + (*n) * j, *n);							
    }
    
    /* for subsets i of cardinality greater than 1 and lower than m */
    for (i=*p+1;i<sb;i++) 
      TA0[k + (*N) * (i - *p - 1)] = empirical_copula_subset(*n, *p, R, subset[i]);
  }
  PutRNGstate();
}

/*****************************************************************************

  Compute TA for subsets of cardinality 2 to p
  R: ranks
  n: sample size
  p: number of variables
  m: max. cardinality of subsets of {1,...,p}
  TA0: simulated values of TA under independence (size: N * (sb - p - 1))
  N: number of repetitions (nrows TA0, fisher0, tippett0)
  subset: subsets of {1,...,p} in binary notation (int) whose card. is 
  between 2 and m in "natural" order
  TA: test statistics (size: sum.bin. - p - 1) 
  pval: corresponding p-values (size = sum.bin. - p - 1)
  fisher: pvalue � la Fisher
  tippett: pvalue � la Tippett
  
******************************************************************************/

void empirical_copula_test(int *R, int *n, int *p, int *m, double *TA0,
			   int *N, int *subset, double *TA, double *pval,
			   double *fisher, double *tippett)			  
{
  int i, j, k, count, sb = (int)sum_binom(*p,*m);
  double *fisher0 = (double *)R_alloc(*N, sizeof(double));
  double *tippett0 = (double *)R_alloc(*N, sizeof(double));
  double pvalue;

  /* compute W � la Fisher and � la Tippett from TA0*/ 
  for (k=0;k<*N;k++) {
    fisher0[k] = 0.0;
    tippett0[k] = 1.0;
    for (i=*p+1;i<sb;i++) {
      /* p-value */
      count = 1;
      for (j=0;j<*N;j++) 
	if (TA0[j + (*N) * (i - *p - 1)] > TA0[k + (*N) * (i - *p - 1)])
	  count ++;
      pvalue = (double)(count)/(*N);
      fisher0[k] -= 2*log(pvalue);
      tippett0[k] = fmin2(tippett0[k],pvalue);
    }
  }

  /* compute W from the current data */
  *fisher = 0.0;
  *tippett = 1.0;
  
  /* for subsets i of cardinality greater than 1 */
  for (i=*p+1;i<sb;i++) 
    {
      TA[i - *p - 1] = empirical_copula_subset(*n, *p, R, subset[i - *p - 1]);
      
      /* p-value */
      count = 1;
      for (k=0;k<*N;k++) 
	if (TA0[k + (*N) * (i - *p - 1)] > TA[i - *p - 1])
	  count ++;
      pval[i - *p - 1] = (double)(count)/(*N +1.0);
      
      *fisher -= 2*log(pval[i - *p - 1]);
      *tippett = fmin2(*tippett,pval[i - *p - 1]);
    }

  /* p-values of the Fisher and Tippett statistics */
  count = 1;
  for (k=0;k<*N;k++) 
    if (fisher0[k] > *fisher)
      count ++;
  *fisher = (double)(count)/(*N +1.0);

  count = 1;
  for (k=0;k<*N;k++) 
    if (tippett0[k] < *tippett)
      count ++;
  *tippett = (double)(count)/(*N +1.0);
}


