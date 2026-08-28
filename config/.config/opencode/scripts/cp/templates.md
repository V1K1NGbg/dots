# Competitive Programming Templates & Snippets

## Java Template (always use this exactly)

```java
import java.io.BufferedReader;
import java.io.InputStreamReader;

import java.util.*;

public final class Comp_Solution {
    public static void main(String[] args) {
        BufferedReader fastin = new BufferedReader(new InputStreamReader(System.in));
        try {
            int test = Integer.parseInt(fastin.readLine().trim());
            while (test-- != 0) {
                solve(fastin);
            }
        } catch (Exception e) {
            System.out.println(e);
        }
    }

    public static void solve(BufferedReader fastin) {
        try {

        } catch (Exception e) {
            System.out.println(e);
        }
    }
}
```

**Rules:** Class name always `Comp_Solution`. Read input via `fastin.readLine()` inside `solve`. Never use `Scanner`.

## Binary Search on Answer

When the answer has monotonic property (if X works, X+1 also works):

```
lo, hi = min_possible, max_possible
while lo < hi:
    mid = (lo + hi) // 2
    if check(mid):
        hi = mid
    else:
        lo = mid + 1
answer = lo
```

## Sliding Window

For subarray/substring problems with a constraint:

```
left = 0
for right in range(n):
    # Add a[right] to window
    while window_invalid():
        # Remove a[left] from window
        left += 1
    # Update answer with window [left, right]
```

## Union-Find (DSU)

```java
int[] par, sz;
void init(int n) {
    par = new int[n]; sz = new int[n];
    for (int i = 0; i < n; i++) { par[i] = i; sz[i] = 1; }
}
int find(int x) { return par[x] == x ? x : (par[x] = find(par[x])); }
void unite(int a, int b) {
    a = find(a); b = find(b);
    if (a == b) return;
    if (sz[a] < sz[b]) { int t = a; a = b; b = t; }
    par[b] = a; sz[a] += sz[b];
}
```

## Modular Arithmetic

```java
static long power(long base, long exp, long mod) {
    long result = 1;
    base %= mod;
    while (exp > 0) {
        if ((exp & 1) == 1) result = result * base % mod;
        base = base * base % mod;
        exp >>= 1;
    }
    return result;
}
static long modinv(long a, long mod) { return power(a, mod - 2, mod); }
```

## Segment Tree

```java
static long[] tree;
static int N;
static void build(int n) { N = n; tree = new long[4 * n]; }
static void update(int pos, long val, int node, int lo, int hi) {
    if (lo == hi) { tree[node] = val; return; }
    int mid = (lo + hi) / 2;
    if (pos <= mid) update(pos, val, 2*node, lo, mid);
    else update(pos, val, 2*node+1, mid+1, hi);
    tree[node] = tree[2*node] + tree[2*node+1];
}
static long query(int l, int r, int node, int lo, int hi) {
    if (r < lo || hi < l) return 0;
    if (l <= lo && hi <= r) return tree[node];
    int mid = (lo + hi) / 2;
    return query(l, r, 2*node, lo, mid) + query(l, r, 2*node+1, mid+1, hi);
}
// Usage: update(pos, val, 1, 0, N-1);  query(l, r, 1, 0, N-1);
```
