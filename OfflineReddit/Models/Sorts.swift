//
//  Sorts.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 24/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation

/*
 These sorts are taken from Reddit's implementation here:
 https://github.com/reddit/reddit/blob/52728820cfc60a9a7be47272ff7fb1031c2710c7/r2/r2/lib/db/_sorts.pyx
 */
struct Sorts {
    
    static func confidence(_ ups: Int64, _ downs: Int64) -> Double {
        /*
         Taken from Reddit's confidence sort here:
         https://github.com/reddit/reddit/blob/52728820cfc60a9a7be47272ff7fb1031c2710c7/r2/r2/lib/db/_sorts.pyx#L70
         They in turn are using this algorithm here:
         http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
         Using the same variable names as the algorthm-
         p is the number of positive ratings,
         n is the total number of ratings,
         confidence refers to the statistical confidence level: pick 0.95 to have 
         a 95% chance that your lower bound is correct, 0.975 to have a 97.5%
         chance, etc. The z-score in this function never changes, so if you don't
         have a statistics package handy or if performance is an issue you can always
         hard-code a value here for z. (Use 1.96 for a confidence level of 0.95.)
         */
        let n = Double(ups + downs)
        if n == 0 {
            return 0
        }
        let z = 1.281551565545 // 80% confidence
        let p = Double(ups) / n
        let left: Double = p + 1 / (2 * n) * z * z
        let right: Double = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n))
        let under: Double = 1 + 1 / n * z * z
        return (left - right) / under
    }
    
    static func controversy(_ ups: Int64, _ downs: Int64) -> Double {
        /* https://github.com/reddit/reddit/blob/52728820cfc60a9a7be47272ff7fb1031c2710c7/r2/r2/lib/db/_sorts.pyx#L60 */
        guard ups > 0, downs > 0 else { return 0 }
        let magnitude = Double(ups + downs)
        let d = Double(downs)
        let u = Double(ups)
        let balance = ups > downs ? d / u : u / d
        return pow(magnitude, balance)
    }
    
    static func hot(_ ups: Int64, _ downs: Int64, _ date: Date) -> Double {
        /*
         https://www.quora.com/Where-do-the-constants-1134028003-and-45000-come-from-in-reddits-hotness-algorithm
         1134028003 is the Unix timestamp for the oldest submission [to Reddit],
         45000 is the number of seconds in 12.5 hours.  
         The way the algo works is that something needs to have 10 times as many 
         points to be "hot" as something 12.5. hours younger.
         */
        let score = Double(ups - downs)
        let order: Double = log10(max(abs(score), 1))
        let sign: Double = score > 0 ? 1 : score < 0 ? -1 : 0
        let seconds = date.timeIntervalSince1970 - 1134028003
        return sign * order + seconds / 45000
    }
}
