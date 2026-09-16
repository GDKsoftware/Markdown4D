# Math showcase

Formulas are written in LaTeX between dollars. Inline, $E = mc^2$ sits in the
sentence at the size of the text around it; a block on its own line is set in
display style, centred, with limits above and below the operators.

## Inline

The quadratic formula gives $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$ for every
$a \neq 0$. Euler's identity $e^{i\pi} + 1 = 0$ ties five constants together,
and $\|v\|_2 = \sqrt{\langle v, v \rangle}$ is the Euclidean norm.

Prices stay text: the seats cost $100 and $200, and `$x$` in code stays code.

## Display

$$
\int_0^\infty e^{-x^2} \, dx = \frac{\sqrt{\pi}}{2}
$$

$$
\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}
$$

$$
f(x) = \begin{cases}
  x^2 & x \geq 0 \\
  -x & \text{otherwise}
\end{cases}
$$

## Matrices and delimiters

$$
\begin{pmatrix} a & b \\ c & d \end{pmatrix}
\begin{pmatrix} x \\ y \end{pmatrix} =
\left( \frac{ax + by}{cx + dy} \right)
$$

$$
\left\lfloor \frac{n}{2} \right\rfloor + \left\lceil \frac{n}{2} \right\rceil = n
$$

## Alphabets and accents

$$
\mathbb{R}^n, \quad \mathcal{L}(f), \quad \mathfrak{g}, \quad \mathbf{v} \cdot \hat{n}, \quad \bar{x}, \quad \vec{F}, \quad \overline{AB}
$$

## Greek and operators

$$
\lim_{h \to 0} \frac{\sin(\alpha + h) - \sin \alpha}{h} = \cos \alpha, \qquad
\nabla \cdot \vec{E} = \frac{\rho}{\varepsilon_0}
$$

## Fence alias and errors

```math
\binom{n}{k} = \frac{n!}{k!\,(n-k)!}
```

An unknown command such as $\nosuchthing{x}$ is drawn by name so you can
see what did not resolve.
