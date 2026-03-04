#!/usr/bin/env python3
"""Watch PhysicsNemo training log and write TensorBoard events.

Runs alongside TensorBoard to provide real-time training metrics visualization.
Parses Hydra-formatted log lines and writes scalar summaries.
"""

import os
import re
import sys
import time
import glob

# Pattern: [2026-03-04 22:01:48,941][train][INFO] - Epoch 1 Metrics: Learning Rate =  1.000e-03, loss =  7.813e-01
EPOCH_RE = re.compile(
    r'\[(?P<ns>\w+)\]\[INFO\]\s*-\s*Epoch\s+(?P<epoch>\d+)\s+Metrics:\s*(?P<metrics>.*)'
)
# Pattern: key = value pairs
METRIC_RE = re.compile(r'([\w\s]+?)\s*=\s*([\d.eE+\-]+)')

# Execution time pattern
TIME_RE = re.compile(
    r'Epoch Execution Time:\s*([\d.eE+\-]+)s,\s*Time/Iter:\s*([\d.eE+\-]+)ms'
)


def parse_metrics(line):
    """Parse a log line for epoch metrics."""
    m = EPOCH_RE.search(line)
    if m:
        epoch = int(m.group('epoch'))
        namespace = m.group('ns')
        metrics = {}
        for km in METRIC_RE.finditer(m.group('metrics')):
            key = km.group(1).strip().replace(' ', '_').lower()
            val = float(km.group(2))
            metrics[f'{namespace}/{key}'] = val
        return epoch, metrics
    return None, None


def parse_time(line, epoch):
    """Parse execution time from a log line."""
    m = TIME_RE.search(line)
    if m:
        return {
            'timing/epoch_time_s': float(m.group(1)),
            'timing/iter_time_ms': float(m.group(2)),
        }
    return None


def find_log_file(search_dirs):
    """Find the most recent training log file."""
    for d in search_dirs:
        for pattern in ['**/*.log', '**/*train*.log']:
            files = glob.glob(os.path.join(d, pattern), recursive=True)
            # Filter to files that contain training output
            for f in sorted(files, key=os.path.getmtime, reverse=True):
                try:
                    with open(f) as fh:
                        content = fh.read(4096)
                        if 'Epoch' in content and 'Metrics' in content:
                            return f
                except (IOError, PermissionError):
                    continue
    return None


def main():
    from torch.utils.tensorboard import SummaryWriter

    log_dir = os.environ.get('TB_LOG_DIR', '/workspace/outputs/tb_events')
    search_dirs = [
        '/workspace/PhysicsNemo',
        '/workspace',
    ]

    os.makedirs(log_dir, exist_ok=True)
    writer = SummaryWriter(log_dir=log_dir)
    print(f'[tb_metrics_writer] Writing TensorBoard events to {log_dir}')

    seen_epochs = set()
    last_epoch = 0
    log_file = None
    log_pos = 0

    while True:
        # Find log file if not found yet
        if log_file is None or not os.path.exists(log_file):
            log_file = find_log_file(search_dirs)
            log_pos = 0
            if log_file:
                print(f'[tb_metrics_writer] Watching: {log_file}')

        if log_file and os.path.exists(log_file):
            try:
                with open(log_file) as f:
                    f.seek(log_pos)
                    new_lines = f.readlines()
                    log_pos = f.tell()

                for line in new_lines:
                    epoch, metrics = parse_metrics(line)
                    if epoch is not None and epoch not in seen_epochs:
                        seen_epochs.add(epoch)
                        last_epoch = epoch
                        for key, val in metrics.items():
                            writer.add_scalar(key, val, epoch)
                        print(f'[tb_metrics_writer] Epoch {epoch}: {metrics}')

                    time_metrics = parse_time(line, last_epoch)
                    if time_metrics and last_epoch in seen_epochs:
                        for key, val in time_metrics.items():
                            writer.add_scalar(key, val, last_epoch)

                writer.flush()
            except (IOError, PermissionError) as e:
                print(f'[tb_metrics_writer] Error reading log: {e}')

        # Also look for validation images
        for img_path in glob.glob('/workspace/PhysicsNemo/**/validation_step_*.png', recursive=True):
            step_match = re.search(r'validation_step_(\d+)', img_path)
            if step_match:
                step = int(step_match.group(1))
                if step not in seen_epochs:
                    continue
                tag = f'validation/step_{step:03d}'
                # Copy to outputs for easy access
                dest = os.path.join('/workspace/outputs', os.path.basename(img_path))
                if not os.path.exists(dest):
                    try:
                        import shutil
                        shutil.copy2(img_path, dest)
                        print(f'[tb_metrics_writer] Copied {img_path} -> {dest}')
                    except (IOError, PermissionError):
                        pass

        time.sleep(10)


if __name__ == '__main__':
    main()
