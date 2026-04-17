pub mod domains {
    pub mod analysis {
        pub fn domain_analyze(value: i64) -> i64 {
            value * 3
        }

        pub fn domain_transform(values: &[i64]) -> Vec<i64> {
            values.iter().map(|x| x * 2 + 1).collect()
        }

        pub fn domain_combine(a: &[i64], b: &[i64]) -> Vec<i64> {
            let mut result = Vec::new();
            for i in 0..std::cmp::min(a.len(), b.len()) {
                result.push(a[i] + b[i]);
            }
            result
        }
    }
}

pub mod analysis_mod {
    pub fn analyze(value: i64) -> i64 {
        value * 2
    }

    pub fn percentile(values: &[f64], p: f64) -> f64 {
        if values.is_empty() {
            return 0.0;
        }
        let mut sorted = values.to_vec();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let idx = (p / 100.0 * (sorted.len() - 1) as f64).round() as usize;
        sorted[idx]
    }

    pub fn variance(values: &[f64]) -> f64 {
        if values.is_empty() {
            return 0.0;
        }
        let mean = values.iter().sum::<f64>() / values.len() as f64;
        values.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / values.len() as f64
    }

    pub fn std_dev(values: &[f64]) -> f64 {
        variance(values).sqrt()
    }

    pub fn correlation(x: &[f64], y: &[f64]) -> f64 {
        if x.len() != y.len() || x.is_empty() {
            return 0.0;
        }
        let n = x.len() as f64;
        let sum_x = x.iter().sum::<f64>();
        let sum_y = y.iter().sum::<f64>();
        let sum_xy = x.iter().zip(y.iter()).map(|(a, b)| a * b).sum::<f64>();
        let sum_x2 = x.iter().map(|v| v * v).sum::<f64>();
        let sum_y2 = y.iter().map(|v| v * v).sum::<f64>();
        let denom = ((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y)).sqrt();
        if denom == 0.0 {
            0.0
        } else {
            (n * sum_xy - sum_x * sum_y) / denom
        }
    }
}

pub fn hello() {
    println!("Hello from Garuda Rust!");
}

pub fn analyze(value: i64) -> i64 {
    value * 2
}

pub fn process_data(data: &[i64]) -> Vec<i64> {
    data.iter().map(|x| x + 1).collect()
}

pub fn compute_stats(values: &[i64]) -> (i64, i64, i64) {
    if values.is_empty() {
        return (0, 0, 0);
    }
    let sum: i64 = values.iter().sum();
    let min = *values.iter().min().unwrap();
    let max = *values.iter().max().unwrap();
    (sum, min, max)
}

pub fn filter_values(data: &[i64], threshold: i64) -> Vec<i64> {
    data.iter().copied().filter(|&x| x > threshold).collect()
}

pub fn transform_values(data: &[i64], f: fn(i64) -> i64) -> Vec<i64> {
    data.iter().map(|&x| f(x)).collect()
}

pub fn merge_results(a: &[i64], b: &[i64]) -> Vec<i64> {
    let mut result = Vec::with_capacity(a.len() + b.len());
    result.extend_from_slice(a);
    result.extend_from_slice(b);
    result.sort();
    result.dedup();
    result
}

pub fn aggregate(values: &[i64], op: &str) -> i64 {
    match op {
        "sum" => values.iter().sum(),
        "min" => *values.iter().min().unwrap_or(&0),
        "max" => *values.iter().max().unwrap_or(&0),
        "avg" => {
            if values.is_empty() {
                0
            } else {
                values.iter().sum::<i64>() / values.len() as i64
            }
        }
        _ => 0,
    }
}

pub fn range_check(value: i64, min_val: i64, max_val: i64) -> bool {
    value >= min_val && value <= max_val
}

pub fn clamp(value: i64, min_val: i64, max_val: i64) -> i64 {
    if value < min_val {
        min_val
    } else if value > max_val {
        max_val
    } else {
        value
    }
}

pub fn normalize(values: &[i64]) -> Vec<f64> {
    if values.is_empty() {
        return vec![];
    }
    let min = *values.iter().min().unwrap() as f64;
    let max = *values.iter().max().unwrap() as f64;
    if (max - min).abs() < f64::EPSILON {
        return vec![0.0; values.len()];
    }
    values
        .iter()
        .map(|&v| (v as f64 - min) / (max - min))
        .collect()
}

pub fn batch_process(data: &[i64], batch_size: usize) -> Vec<Vec<i64>> {
    data.chunks(batch_size)
        .map(|chunk| chunk.to_vec())
        .collect()
}

pub fn rolling_window(data: &[i64], window: usize) -> Vec<i64> {
    if data.len() < window || window == 0 {
        return vec![];
    }
    data.windows(window).map(|w| w.iter().sum()).collect()
}

pub fn cumulative_sum(values: &[i64]) -> Vec<i64> {
    let mut result = Vec::with_capacity(values.len());
    let mut sum = 0i64;
    for &v in values {
        sum += v;
        result.push(sum);
    }
    result
}

pub fn moving_average(data: &[f64], window: usize) -> Vec<f64> {
    if data.len() < window || window == 0 {
        return vec![];
    }
    let mut result = Vec::with_capacity(data.len() - window + 1);
    let mut sum: f64 = data[..window].iter().sum();
    result.push(sum / window as f64);
    for i in window..data.len() {
        sum = sum - data[i - window] + data[i];
        result.push(sum / window as f64);
    }
    result
}

pub fn exponential_moving_average(data: &[f64], alpha: f64) -> Vec<f64> {
    if data.is_empty() || alpha <= 0.0 || alpha >= 1.0 {
        return vec![];
    }
    let mut result = Vec::with_capacity(data.len());
    if let Some(&first) = data.first() {
        result.push(first);
        for &val in &data[1..] {
            let ema = alpha * val + (1.0 - alpha) * result.last().unwrap();
            result.push(ema);
        }
    }
    result
}
