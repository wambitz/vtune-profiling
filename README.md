# vtune‑demo

A **single‑CMake‑target sandbox** that demonstrates how to collect a Hotspots
profile for a native binary with Intel® VTune™ Profiler using **two distinct
flows**:

| Flow            | Where VTune lives           | Best for                         | TL;DR script                                         |
| --------------- | --------------------------- | -------------------------------- | ---------------------------------------------------- |
| **A** (default) | *Inside a Docker container* | isolated, repeatable runs; CI    | [`profile_host_binary.sh`](./profile_host_binary.sh) |
| **B**           | *Installed on the host OS*  | full GUI, low‑overhead dev boxes | see the **Host‑VTune** section below                 |

Both methods work against the same tiny workload (`prime_counter`) yet differ
in setup cost, privileges required, and how results are handled.  Pick the one
that matches your environment; keep the other as a fallback or reference.

---

## Folder layout

```
.
├── build.sh               # compiles prime_counter → build/prime_counter
├── profile_host_binary.sh # default: profile via VTune container
├── CMakeLists.txt         # one‑target CMake project
└── main.cpp               # naive prime counter – burns CPU for the demo
```

`build.sh` and `profile_host_binary.sh` are intentionally dependency‑free Bash
scripts so they work on any modern Linux distro with Docker.

---

## Build the workload (common step)

```bash
./build.sh        # → build/prime_counter
```

The target is compiled with `-O3 -g -fno‑omit‑frame‑pointer` so VTune can show
accurate call stacks while still being optimised enough to generate hotspots.

---

## Approach A — Profile via **VTune inside Docker** (recommended default)

<details>
<summary><strong>Why this is the default</strong></summary>

* No packages installed on the host – keeps your workstation clean.
* Fully reproducible: each run uses the exact same VTune build.
* Works on CI where installing VTune system‑wide is not allowed.
* Results are bind‑mounted back to the host and automatically `chown`‑ed to
  your UID ⇒ you can delete them without `sudo`.

</details>

### Prerequisites

| Tool       | Version                      | Notes                                                                                             |
| ---------- | ---------------------------- | ------------------------------------------------------------------------------------------------- |
| **Docker** | ≥ 20.10                      | Needs the `--privileged` flag *or* two capabilities.<br>Both variants are included in the script. |
| **sysctl** | `kernel.yama.ptrace_scope=0` | Only required if you use the non‑privileged path with `CAP_SYS_PTRACE`.                           |

### One‑liner

```bash
./profile_host_binary.sh
```

Under the hood the script offers **three recipes** (only one is active):

* **A1** – non‑root + `SYS_PTRACE` + `PERFMON` (least privilege)
* **A2** – `--privileged` + inline `chown` (zero host tweaks)
* **A3** – raw root (fastest to paste; leaves root‑owned files)

Comment/uncomment inside the script to switch.

### Where the report lands

```
vtune_results/              # bind‑mounted as /home/vtune
└── results/                # default result‑dir inside the container
    ├── hotspots.txt        # tiny summary
    ├── ...                 # full .sql, .pb files for VTune GUI
```

Open it with the standalone GUI or the CLI reporter:

```bash
vtune -report hotspots -r vtune_results/results
```

---

## Approach B — Profile via **VTune installed on the host**

Use this path when you already have oneAPI VTune on your workstation and want
native integration with the GUI, Eclipse,*etc.*  No Docker required.

### 3.1  Prerequisites

* **Intel oneAPI Base Toolkit** or **VTune standalone** installed under
  `/opt/intel/oneapi` (or your custom path).
* The sampling driver is optional for timer‑based Hotspots but required for
  Microarchitecture Insights / Memory Access.

```bash
# load the oneAPI environment once per shell
source /opt/intel/oneapi/setvars.sh

# (optional) load the SEP driver for HW events – needs sudo the first time
sudo vtune -kernel-collect on
```

### 3.2  Collect Hotspots

```bash
./build.sh                                    # if not built yet

vtune -collect hotspots \
      -result-dir vtune_results_host \
      -- ./build/prime_counter
```

After a few seconds the CLI prints a summary and stores the full result in
`vtune_results_host/`.  Open it with either:

```bash
vtune-gui vtune_results_host &            # launches the GUI directly
# or
vtune -report hotspots -r vtune_results_host
```

#### Attaching to an already running process

```bash
# find target PID
pidof prime_counter   # or ps ‑C prime_counter

vtune -collect hotspots -target-process $PID -duration 10s -r attach_results
```

#### Attaching to a binary **inside a container**

If the workload itself runs in Docker but VTune is on the host:

```bash
# run container sharing the host PID namespace so VTune can see the process ID
CID=$(docker run -d --pid=host myimage /usr/local/bin/my_app)
PID=$(docker inspect --format '{{.State.Pid}}' $CID)

sudo vtune -collect hotspots -target-process $PID -r container_results
```

> ℹ️ Hardware sampling works as long as the process is in the same PID
> namespace and you capture as **root or perf‑event‑trusted user**.

---

## Pros / Cons at a glance

| Criterion                  | Docker VTune (A)                  | Host VTune (B)          |
| -------------------------- | --------------------------------- | ----------------------- |
| Host install needed        | **No**                            | Yes (≫ 2 GB)            |
| Reproducible toolchain     | **Yes** – fixed image tag         | Depends on host updates |
| Requires `sudo` during run | Not if using caps                 | Only for SEP driver     |
| Result ownership           | Correct by default                | Correct by default      |
| GUI responsiveness         | VNC/X11 over container (slower)   | **Native**              |
| Ideal for                  | CI pipelines, ephemeral dev boxes | Daily desktop use       |

---

## Cleaning up everything

```bash
rm -rf build vtune_results vtune_results_host
# Optional: free ≈1 GB of image layers
docker image rm intel/oneapi-vtune:latest || true
```

---

### Footnotes

*`prime_counter` counts primes up to 100 000 using an intentionally inefficient
trial‑division loop – plenty of easy hotspots for VTune to visualise.*

PRs for additional analyses (**memory‑access**, **GPU Hotspots**, *etc.*) are
welcome.
