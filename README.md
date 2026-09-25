# Taylor-Series-in-RISC-V
# Objective

The program accepts multiple function specifications from the data
segment. For each specification, it computes the requested Taylor series
approximation up to the specified number of terms and stores the
resulting FP32 value in memory starting from address `0x10000200`.

The implementation was designed in a modular manner using separate
subroutines for each supported function.

# Input and Output Format

The input data is stored in the data segment starting at address
`0x10000000` in the following format:

    N, func1_code, func1_x, func1_terms,
       func2_code, func2_x, func2_terms, ...

where:

- $N$ is the total number of function values to be computed.

- `func_code` identifies the required function.

- $x$ is represented as an IEEE-754 single-precision floating-point
  value.

- `terms` specifies the number of Taylor-series terms.

The function codes are:

::: center
   **Function Code**   **Function**

------------------- --------------

           0            $\exp(x)$
           1            $\sin(x)$
           2            $\cos(x)$
           3             $\ln(x)$
           4              $1/x$

:::

The results are stored sequentially starting at:

::: center
`0x10000200`
:::

Each result occupies one 32-bit word.

# Assumptions and Input Constraints

The problem statement guarantees that the input values lie within the
convergence domain of the corresponding Taylor series. Therefore, no
additional convergence-domain checking is required.

The required mathematical domain checks are nevertheless performed:

::: center
   **Function**    **Valid Domain**

-------------- --------------------

    $\exp(x)$     $x \in \mathbb{R}$
    $\sin(x)$     $x \in \mathbb{R}$
    $\cos(x)$     $x \in \mathbb{R}$
     $\ln(x)$          $x > 0$
      $1/x$           $x \neq 0$

:::

The following cases return an FP32 NaN:

1.  Invalid function code, i.e. a code other than $0$--$4$.

2.  Number of terms less than or equal to zero.

3.  Input outside the mathematical domain of the specified function.

# Overall Program Design

The program consists of an initialization section, an input-processing
loop, function-code dispatch logic, individual mathematical subroutines,
a common NaN handler, and an output-storage section.

The overall execution flow is:

1.  Initialize the input and output pointers.

2.  Read $N$ from the data segment.

3.  Read the function code, $x$, and the number of terms.

4.  Validate the number of terms.

5.  Dispatch execution to the corresponding function subroutine.

6.  Perform the Taylor-series computation.

7.  Return the result in `f10`.

8.  Store the result at the current output address.

9.  Advance the input and output pointers.

10.  Repeat until all $N$ function values have been processed.

Each input record occupies 12 bytes:

$$\text{function code (4 bytes)}
+
x\text{ (4 bytes)}
+
\text{terms (4 bytes)}.$$

After processing one input, the input pointer is advanced by 12 bytes,
while the output pointer is advanced by 4 bytes.

# Taylor-Series Implementation

Instead of calculating powers and factorials independently for every
term, each function is implemented using a recurrence relation between
successive Taylor-series terms.

This avoids repeated computation of quantities such as $x^n$ and $n!$,
and reduces the number of arithmetic operations required for each
additional term.

The implementation also avoids unnecessary memory accesses. An
alternative approach would be to precompute powers and factorials and
store them in memory, but this would introduce additional load/store
operations. Since the intermediate values are small in number, keeping
them in registers is more suitable for this implementation.

## Exponential Function

The Taylor expansion used is

$$e^x =
1 + x + \frac{x^2}{2!}

+ \frac{x^3}{3!}
+ \cdots$$

If the current term is

$$T_{i-1} = \frac{x^{i-1}}{(i-1)!},$$

the next term is calculated as

$$T_i = T_{i-1}\frac{x}{i}.$$

Thus, each new term requires only a division and multiplication.

## Sine Function

The Taylor expansion used is

$$\sin(x) =
x-\frac{x^3}{3!}
+\frac{x^5}{5!}
-\frac{x^7}{7!}
+\cdots$$

The implementation precomputes

$$x^2$$

and generates successive terms using

$$T_k =
T_{k-1}
\frac{x^2}{(2k)(2k+1)}.$$

The sign is selected using the parity of the loop counter.

## Cosine Function

The Taylor expansion used is

$$\cos(x) =
1-\frac{x^2}{2!}
+\frac{x^4}{4!}
-\frac{x^6}{6!}
+\cdots$$

The successive terms are generated using

$$T_k =
T_{k-1}
\frac{x^2}{(2k-1)(2k)}.$$

Again, the parity of the loop counter determines whether the current
term is added or subtracted.

## Natural Logarithm

The series specified in the problem is

$$\ln(x)
=
(x-1)
-\frac{(x-1)^2}{2}
+\frac{(x-1)^3}{3}
-\frac{(x-1)^4}{4}
+\cdots$$

Let

$$y=x-1.$$

The implementation starts with the first term $y$ and then successively
generates powers of $y$:

$$y,\quad y^2,\quad y^3,\quad y^4,\ldots$$

while increasing the denominator from $2$ onwards.

## Reciprocal Function

The reciprocal is calculated using

$$\frac{1}{x}
=
1-(x-1)
+(x-1)^2
-(x-1)^3
+\cdots$$

Let

$$y=x-1.$$

The first term is $1$, and every subsequent term is obtained by
multiplying the previous term by $y$. The sign alternates according to
the parity of the term index.

# Register Usage

The implementation uses integer and floating-point registers for program
control, addressing, function arguments, Taylor-series intermediate
values, and output management.

The following table summarizes the role of each register used throughout
the program.

  **Reg.**   **ABI Name**   **Role in Program**

---------- -------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------

  **Reg.**   **ABI Name**   **Role in Program**
  `x0`       `zero`         Constant zero. Used as a source for zero values, comparisons, and unconditional jumps such as `jal x0, label`.
  `x1`       `ra`           Return-address register. Stores the return address generated by `jal` when calling each mathematical subroutine.
  `x3`       `gp`           Used in this program as the input-data pointer. Initially points to `0x10000000` and is advanced by 12 bytes after each input specification.
  `x5`       `t0`           Counts how many function specifications have been processed. Compared with $N$ to terminate the main loop.
  `x6`       `t1`           Function-code dispatch register. Starts from zero and is incremented to identify function codes 0 through 4.
  `x7`       `t2`           Integer constant $1$. Used for comparisons such as `terms == 1`, parity checks, and domain-check results.
  `x10`      `a0`           Number of Taylor-series terms passed to each subroutine. It is also used as a function argument register and may be modified by `exp`.
  `x18`      `s2`           Stores the total number of function values, $N$.
  `x19`      `s3`           Stores the function code for the current input record.
  `x28`      `t3`           Temporary integer register. Used for parity calculations and temporary results of floating-point comparison instructions.
  `x29`      `t4`           Taylor-series loop counter. Reset before calling a function and incremented during the evaluation of the series. It is also temporarily used for some domain checks.
  `x30`      `t5`           Output-data pointer. Initially points to `0x10000200` and is increased by 4 bytes after every result.
  `x31`      `t6`           Holds the integer representation of the FP32 NaN value, `0x7FC00000`.
  `f0`       `ft0`          Floating-point constant $+0.0$.
  `f1`       `ft1`          Floating-point constant $1.0$.
  `f2`       `ft2`          Temporary floating-point register. Used for small constants/intermediate values where required.
  `f3`       `ft3`          Accumulated Taylor-series sum and final intermediate result in all mathematical subroutines.
  `f4`       `ft4`          Current Taylor-series term. Updated at every iteration.
  `f5`       `ft5`          Temporary floating-point value. Its exact meaning depends on the function; for example, it stores a term ratio or $x-1$.
  `f6`       `ft6`          Temporary floating-point register used for denominator factors, denominator values, or constants depending on the function.
  `f7`       `ft7`          Temporary floating-point register used for denominator factors or intermediate terms.
  `f8`       `fs0`          Temporary floating-point register used mainly for the product of denominator factors in the sine and cosine calculations.
  `f9`       `fs1`          Stores the precomputed value $x^2$ in the sine and cosine calculations.
  `f10`      `fa0`          Main floating-point argument and return-value register. Contains input $x$ before a function call and the computed result after the subroutine returns.
  `f31`      `ft11`         Contains the FP32 NaN value used by the common error-handling path.

# ABI and Subroutine Convention

The implementation follows the standard calling convention for the main
function arguments and return value.

The input floating-point value $x$ is passed in `f10` (`fa0`), while the
number of terms is passed in `x10` (`a0`). Each mathematical subroutine
returns its result in `f10`.

The return address is passed through `x1` (`ra`):

``` {.[x86masm]Assembler language="[x86masm]Assembler"}
jal  x1, exp
...
jalr x0, 0(x1)
```

The temporary integer registers used by the subroutines are
caller-saved, which is appropriate for intermediate calculations.

The implementation should preserve callee-saved registers whenever
strict ABI compliance is required. In particular, registers identified
by the ABI as callee-saved should not be modified without saving and
restoring their previous values.

# Error Handling

A common error-handling path is used to return NaN.

An FP32 NaN value is represented using the bit pattern

    0x7FC00000

The integer representation is prepared in `x31` and then made available
as a floating-point NaN in `f31`.

When an invalid input is detected, the program executes the common `nan`
label and places the NaN value in `f10`, after which it is stored in the
output array.

The following conditions are handled:

- invalid function code,

- number of terms $\leq 0$,

- $x \leq 0$ for $\ln(x)$,

- $x=0$ for $1/x$.

# Memory Management

The program uses separate input and output pointers.

The initial addresses are:

$$\text{Input base} = \texttt{0x10000000}$$

$$\text{Output base} = \texttt{0x10000200}.$$

For each function specification:

$$\text{Input pointer} \leftarrow
\text{Input pointer}+12$$

and after storing the result:

$$\text{Output pointer} \leftarrow
\text{Output pointer}+4.$$

This ensures that every input specification is processed exactly once
and that the corresponding outputs are stored sequentially.

# Optimization Considerations

A direct implementation of the Taylor expansions could compute every
power and factorial independently. However, such an implementation would
perform redundant calculations.

Another possibility would be to precompute powers and factorials and
store them in memory. Although this could reduce repeated arithmetic, it
would increase the number of memory accesses and require additional
storage.

The chosen implementation instead uses recurrence relations between
successive terms. This approach:

- avoids repeated power and factorial calculations,

- keeps frequently used intermediate values in registers,

- reduces unnecessary memory accesses,

- makes the implementation suitable for low-level assembly.

# Verification

The implementation was verified using an independent reference
implementation written in C.

The C implementation computes the same Taylor-series expansions using
single-precision floating-point variables. It was used to obtain
expected results for a collection of test inputs.

The verification process included the following types of tests:

- basic tests for each supported function,

- different numbers of Taylor-series terms,

- $\texttt{terms}=1$ cases,

- values around important points such as $x=0$ and $x=1$,

- positive and negative inputs where applicable,

- invalid function codes,

- invalid numbers of terms,

- invalid domains for $\ln(x)$ and $1/x$,

- manually selected random inputs within the allowed convergence
  domains.

The comparison was performed using FP32 values so that the reference
implementation matched the single-precision arithmetic used by the
RISC-V F-extension instructions.

For a stronger verification method, the 32-bit IEEE-754 bit pattern of
the output can be compared directly rather than comparing only decimal
floating-point values.

# Debugging and Development Challenges

Debugging the implementation was challenging because the program
contains multiple subroutines, branch paths, floating-point
calculations, and input/output pointer updates.

One significant issue occurred due to an ordering error in the main
input-processing section. The input value $x$ was loaded into the
floating-point argument register `f10`, but an instruction later
overwrote `f10` before the function subroutine was called. This caused
incorrect results and was difficult to identify because the
Taylor-series subroutines themselves were not responsible for the error.

Another debugging issue involved maintaining the correct input and
output addresses. Since the input and output pointers are updated
independently, an incorrect update can cause all subsequent outputs to
be shifted.

During development, the NaN generation mechanism was also simplified.
Initially, the integer representation of NaN was stored in memory and
then loaded into an FP register. It was later observed that the value
could be moved directly between integer and floating-point registers
using:

``` {.[x86masm]Assembler language="[x86masm]Assembler"}
fmv.w.x f31, x31
```

This removes an unnecessary store/load pair.

# Conclusion

The final implementation provides modular RISC-V F-extension subroutines
for $\exp(x)$, $\sin(x)$, $\cos(x)$, $\ln(x)$, and $1/x$.

The functions evaluate the required Taylor series using recurrence
relations rather than repeatedly calculating powers and factorials. This
reduces redundant arithmetic and minimizes unnecessary memory
operations.

The program also handles invalid function codes, invalid term counts,
and function-specific domain errors by returning an FP32 NaN.

The use of separate subroutines, clearly defined registers, and
dedicated input/output pointers provides a structured implementation
that is easier to test and debug. Verification using an independent C
reference implementation provided a practical method for checking the
numerical correctness of the generated FP32 results.
