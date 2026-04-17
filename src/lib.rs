pub mod garuda {
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
}
