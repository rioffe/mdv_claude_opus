# Code highlighting

Nine languages (K-05), Swift and SQL (R-38), C++, Metal, OpenCL, JSON, Lua, Perl and Markdown (R-43), an unknown fence, and prompt-aware fences (R-08, T-06, T-37, T-51).

```c
#include <stdio.h>
int main(void) { printf("%d\n", 42); return 0; } /* c */
```

```go
package main
func main() { s := "hi"; println(s) } // go
```

```rust
fn main() { let x: u32 = 7; println!("{}", x); } // rust
```

```bash
for f in *.txt; do echo "$f"; done # bash
```

```javascript
function f(a) { return `x${a}` + 3 } // js
```

```yaml
key: value
list:
  - 1
  - "two" # yaml
```

```toml
[table]
name = "x"
n = 3 # toml
```

```python
def f(x):
    return "s" + str(3)  # python
```

```ruby
def f(x)
  "s" + 3.to_s # ruby
end
```

```swift
// MARK: - Model
struct Counter {
    @Published var count: Int = 42
    func bump(by n: Int) -> String {
        guard let x = Optional(n) else { return "none" }
        return "count is \(count + x)"
    }
}
```

```sql
-- users and their orders
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
SELECT u.name, COUNT(o.id) FROM users u JOIN orders o ON o.user_id = u.id WHERE u.name = 'alice' AND o.total > 100;
```

```postgresql
-- the same block, tagged postgresql, highlights identically to sql
SELECT u.name, COUNT(o.id) FROM users u JOIN orders o ON o.user_id = u.id WHERE u.name = 'alice' AND o.total > 100;
```

```cpp
// a counter
#include <cstdint>
struct Counter {
    std::uint32_t n = 42;
    const char *name = "counter";
    int bump(int by) { return n + by; }
};
```

```metal
#include <metal_stdlib>
using namespace metal;

// scales in place
kernel void scale(device float4 *v [[buffer(0)]], uint i [[thread_position_in_grid]]) {
    v[i] = v[i] * 2.0f;
}
```

```opencl
/* vector add */
__kernel void vec_add(__global const float *a, __global float *c, const int n) {
    int i = get_global_id(0);
    if (i < n) c[i] = a[i] + 1.5f;
}
```

```json
{ "name": "mdv6", "count": 42, "ok": true }
```

```lua
-- counts to n
local function sum(n)
    local t = 0
    for i = 1, n do t = t + i end
    return t, "done"
end
```

```perl
#!/usr/bin/perl
use strict;
my $count = 42;          # a comment
sub greet {
    my ($name) = @_;
    print "hello, $name\n";
    return $count > 10 ? "big" : 'small';
}
```

```markdown
# A heading

A paragraph with **bold**, _italic_, `code span` and a [link](https://example.com).

- a list item

> a quote
```

```brainfuck
+++++[>+++++<-]>.
```

```bash
$ ls -la
total 0
$ echo hi
hi
```

```console
$ ls -la
total 0
$ echo hi
hi
```

```fish
$ ls -la
total 0
$ echo hi
hi
```

```shell-session
$ ls -la
total 0
$ echo hi
hi
```

```powershell
$ ls -la
total 0
$ echo hi
hi
```
