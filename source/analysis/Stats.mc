import Toybox.Lang;

module Stats {

    // Median of the values, or null for an empty array. The input array is not modified.
    function median(values as Array) as Float? {
        var n = values.size();
        if (n == 0) {
            return null;
        }
        var copy = values.slice(0, null);
        if (n % 2 == 1) {
            return select(copy, n / 2).toFloat();
        }
        return (select(copy, n / 2 - 1).toFloat() + select(copy, n / 2).toFloat()) / 2.0;
    }

    // k-th smallest value (0-based) via quickselect. Linear on average, unlike sorting,
    // so the 300 calibration samples stay well clear of the watchdog limit. Reorders the array.
    function select(a as Array, k as Number) as Numeric {
        var lo = 0;
        var hi = a.size() - 1;
        while (lo < hi) {
            var pivot = a[(lo + hi) / 2];
            var i = lo;
            var j = hi;
            while (i <= j) {
                while (a[i] < pivot) {
                    i++;
                }
                while (a[j] > pivot) {
                    j--;
                }
                if (i <= j) {
                    var tmp = a[i];
                    a[i] = a[j];
                    a[j] = tmp;
                    i++;
                    j--;
                }
            }
            if (k <= j) {
                hi = j;
            } else if (k >= i) {
                lo = i;
            } else {
                return a[k];
            }
        }
        return a[k];
    }
}
