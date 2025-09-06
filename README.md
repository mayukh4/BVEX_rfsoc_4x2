# BVEX RFSoC Spectrometer & VLBI System

CASPER-based FPGA designs and control software for RFSoC 4x2 platforms running radio astronomy spectrometer and VLBI data acquisition systems.

## System Overview

This repository contains FPGA designs and Python control software for:
- 120 kHz resolution spectrometer for water maser observations
- 2-bit requantized 100GbE VLBI data acquisition system
- Real-time data processing and UDP streaming capabilities

## Hardware Requirements

- RFSoC 4x2 FPGA board
- CASPER toolflow compatible environment
- 100GbE network infrastructure for VLBI operations
- GPS/timing reference for VLBI synchronization

## FPGA Designs

### Spectrometer Design (120 kHz Resolution)

**Configuration:**
- FFT Size: 16,384 points
- Frequency Resolution: ~120 kHz
- Sample Rate: 3932.16 MSPS
- Bandwidth: 1966.08 MHz
- Target: Water maser observations at 22.235 GHz

**Key Features:**
- 16k-point FFT processing
- Water maser zoom window extraction (±10 MHz around 22.235 GHz)
- Real-time baseline subtraction
- Shared memory interface for UDP streaming
- Optimized BRAM readout with concurrent processing

### VLBI Design (2-bit Requantization)

**Components:**

#### Dynamic Requantizer (`dynamic_requantizer.vhd`)
- Input: 8 complex samples (16 × 16-bit values)
- Output: 8 complex samples (16 × 2-bit values)
- Fixed threshold quantization for VLBI compatibility

#### Packer (`packer.vhd`)
- Converts 32-bit requantized words to 256-bit packed format
- 8:1 packing ratio with shift register implementation
- Clock enable support for Xilinx integration

#### Timestamp Generator (`timestamp_gen_simple.vhd`)
- VDIF-compatible timestamp generation
- PPS counter tracking seconds since VDIF epoch (Jan 1, 2000)
- Cycle counter for sub-second timing
- 3-stage synchronizer for PPS signal stability

## Python Control Software

### Spectrometer Control (`rfsoc_spec_120khz.py`)

**Functionality:**
- FPGA configuration and initialization
- Real-time spectrum acquisition and processing
- Water maser data processing pipeline
- File rotation and data archiving
- Performance optimization with configurable flush/sync intervals

**Key Parameters:**
```python
FFT_SIZE = 16384
FREQUENCY_RESOLUTION = 0.120  # MHz
WATER_MASER_FREQ = 22.235     # GHz
ZOOM_WINDOW_WIDTH = 0.010     # GHz (±10 MHz)
```

**Usage:**
```bash
python rfsoc_spec_120khz.py <hostname> <log_path> <mode> [options]
```

**Options:**
- `-l, --acc_len`: Accumulation length
- `-i, --interval`: Data save interval (seconds)
- `-p, --path`: Data save path
- `--flush-every`: Flush frequency for performance optimization
- `--timing`: Enable timing analysis

### VLBI Data Logger (`vlbi_data_logging_listener.py`)

**Functionality:**
- VLBI packet capture and validation
- Timestamp extraction and verification
- Real-time data quality monitoring
- File rotation with metadata logging
- PPS reset behavior detection

**Packet Structure:**
- Total Size: 8,298 bytes
- Header Size: 64 bytes
- PPS Counter: Bytes 4-7 (Little Endian)
- Cycles Counter: Bytes 8-11 (Little Endian)

**Usage:**
```bash
python vlbi_data_logging_listener.py <hostname> [options]
```

**Options:**
- `-n, --numpkt`: Packets per sequence
- `-s, --skip`: Skip FPGA programming
- `-d, --datadir`: Output directory
- `-a, --adc`: ADC channel selection

## Data Processing Pipeline

### Spectrometer Pipeline
1. FPGA accumulation and readout
2. FFT shift and spectrum flipping
3. dB conversion (10 × log₁₀)
4. Water maser zoom window extraction
5. Baseline calculation and subtraction
6. Shared memory update for UDP streaming

### VLBI Pipeline
1. 16-bit to 2-bit requantization
2. 32-bit to 256-bit packing
3. Timestamp insertion (PPS + cycles)
4. 100GbE packet transmission
5. Data validation and quality monitoring

## Configuration Files

### Bitstream Files
- Spectrometer: `rfsoc4x2_tut_spec_cx_14pt_fft_*.fpg`
- VLBI: `rfsoc4x2_stream_rfdc_100g_4096_timestamping_2bit_*.fpg`

### Register Map
- `acc_len`: Accumulation length control
- `adc_chan_sel`: ADC channel selection (0-3)
- `cnt_rst`: Counter reset control
- `pkt_rst`: Packet reset control
- `qsfp_rst`: QSFP port enable/disable

## Shared Memory Interface

**Structure:**
- Ready flag (4 bytes)
- Active type (4 bytes)
- Timestamp (8 bytes)
- Data size (4 bytes)
- Baseline value (8 bytes)
- Spectrum data (167 × 8 bytes)

**Memory Name:** `/dev/shm/bcp_spectrometer_data`

## Performance Optimization

### Spectrometer Optimizations
- Concurrent BRAM readout with ThreadPoolExecutor
- Configurable flush intervals to reduce I/O overhead
- Timing analysis for bottleneck identification
- Optimized file sync frequencies

### VLBI Optimizations
- Pipelined requantization and packing
- Clock enable gating for power efficiency
- 3-stage PPS synchronizer for timing stability
- Stable timestamp capture mechanism

## Known Issues

### VLBI Timestamp Generation
- PPS counter: Working correctly with VDIF epoch compatibility
- Cycles counter: Reset mechanism under development
- Current implementation uses captured values for stability

### Timing Constraints
- 256 MHz system clock requirements
- PPS signal synchronization criticality
- Network latency considerations for 100GbE

## Dependencies

**Python Requirements:**
- numpy
- casperfpga
- struct
- threading
- multiprocessing

**System Requirements:**
- CASPER toolflow
- Xilinx Vivado (for FPGA synthesis)
- Linux-based control system
- Network infrastructure for data distribution

## Data Output

### Spectrometer Output
- Timestamped spectrum files (.txt format)
- Integrated power measurements
- Metadata with processing parameters
- Real-time UDP streams via shared memory

### VLBI Output
- Binary packet files (.bin format)
- JSON metadata with timestamp analysis
- Quality monitoring reports
- File rotation based on time intervals

## Monitoring and Diagnostics

### Real-time Monitoring
- Packet capture rates and data quality
- Timestamp validation and PPS behavior
- File rotation and storage management
- Performance metrics and bottleneck analysis

### Quality Metrics
- Timestamp success rates
- PPS increment tracking
- Cycles reset detection
- Data integrity validation
