//
//  TaskTitleConverter.swift
//  Dad App
//
//  Created by Ashley Davison on 29/03/2025.
//

import Foundation

class TaskTitleConverter {
    static let shared = TaskTitleConverter()
    
    // Private initializer for singleton
    private init() {}
    
    // Main function to convert task title from future to past tense
    func convertToPastTense(title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip conversion for very short titles
        if trimmedTitle.count < 3 {
            return "Completed: " + trimmedTitle
        }
        
        // First check for common prefixes and remove them
        let (cleanedTitle, removedPrefix) = removeCommonPrefixes(title: trimmedTitle)
        
        // Split the title into words for analysis
        let words = cleanedTitle.components(separatedBy: " ")
        
        // Check if we have enough words to work with
        if words.isEmpty {
            return "Completed: " + trimmedTitle
        }
        
        // Check if the title already starts with "Completed:" or similar
        if isAlreadyPastTense(title: cleanedTitle) {
            return cleanedTitle
        }
        
        // Analyze the sentence structure to identify the main verb and its position
        let (verbPosition, verbForm) = identifyMainVerb(words: words)
        
        // Convert the sentence using the identified verb position and form
        let convertedTitle: String
        if verbPosition >= 0 {
            convertedTitle = convertSentenceWithVerb(words: words, verbPosition: verbPosition, verbForm: verbForm, hadPrefix: !removedPrefix.isEmpty)
        } else {
            // Fallback if we couldn't identify a main verb
            convertedTitle = "Completed: " + cleanedTitle
        }
        
        return convertedTitle
    }
    
    // Remove common task prefixes like "I need to", "Remember to", etc.
    private func removeCommonPrefixes(title: String) -> (cleanedTitle: String, removedPrefix: String) {
        let prefixes = [
            "i need to ", "need to ", "have to ", "i have to ",
            "remember to ", "don't forget to ", "must ", "should ",
            "i must ", "i should ", "to ", "i want to ", "want to ",
            "i'd like to ", "i would like to ", "please ", "we need to ",
            "we have to ", "we should ", "we must ", "please remember to ",
            "gotta ", "make sure to ", "can you ", "could you "
        ]
        
        let lowercaseTitle = title.lowercased()
        
        for prefix in prefixes {
            if lowercaseTitle.hasPrefix(prefix) {
                // Remove the prefix, preserving the original case of the rest
                let startIndex = title.index(title.startIndex, offsetBy: prefix.count)
                return (String(title[startIndex...]), prefix)
            }
        }
        
        return (title, "")
    }
    
    // Check if the title is already in past tense
    private func isAlreadyPastTense(title: String) -> Bool {
        let pastTensePrefixes = [
            "completed: ", "completed ", "done: ", "done ",
            "finished: ", "finished ", "already "
        ]
        
        let lowercaseTitle = title.lowercased()
        
        for prefix in pastTensePrefixes {
            if lowercaseTitle.hasPrefix(prefix) {
                return true
            }
        }
        
        // Check for common past tense verb patterns
        let words = lowercaseTitle.components(separatedBy: " ")
        if let firstWord = words.first,
           (firstWord.hasSuffix("ed") && firstWord != "need" && firstWord != "reed") ||
           isPastTenseIrregularVerb(firstWord) {
            return true
        }
        
        return false
    }
    
    // Check if a word is an irregular past tense verb
    private func isPastTenseIrregularVerb(_ word: String) -> Bool {
        let pastTenseIrregulars = Set([
            "was", "were", "went", "did", "made", "got", "took", "brought",
            "caught", "came", "found", "gave", "sent", "paid", "met", "read",
            "wrote", "built", "spoke", "told", "thought", "bought", "felt",
            "had", "heard", "held", "kept", "knew", "left", "led", "lost",
            "put", "ran", "saw", "sold", "sat", "stood", "wore"
        ])
        
        return pastTenseIrregulars.contains(word)
    }
    
    // Identify the main verb and its form in the sentence
    private func identifyMainVerb(words: [String]) -> (position: Int, form: VerbForm) {
        // First check for auxiliary verbs that might indicate complex structures
        // Example: "will call", "have purchased", "am going to buy"
        
        if words.count > 1 {
            // Check for auxiliary + verb patterns
            for i in 0..<words.count-1 {
                let current = words[i].lowercased()
                
                // Look for auxiliary verbs
                if ["am", "are", "is", "was", "were", "will", "would", "should", "could", "can", "may", "might", "must", "have", "has", "had"].contains(current) {
                    return (i+1, determineVerbForm(word: words[i+1].lowercased(), previous: current))
                }
                
                // Check for "going to <verb>" pattern
                if current == "going" && i < words.count-2 && words[i+1].lowercased() == "to" {
                    return (i+2, .base)
                }
            }
        }
        
        // If no auxiliary pattern is found, assume the first word might be a verb
        if !words.isEmpty {
            return (0, determineVerbForm(word: words[0].lowercased(), previous: nil))
        }
        
        return (-1, .unknown)
    }
    
    // Convert the sentence using the identified verb information
    private func convertSentenceWithVerb(words: [String], verbPosition: Int, verbForm: VerbForm, hadPrefix: Bool) -> String {
        var resultWords = words
        
        // Get the verb word
        let verb = words[verbPosition].lowercased()
        
        // Convert the verb based on its form
        let convertedVerb = convertVerbToPastTense(verb: verb, form: verbForm)
        
        // Replace the verb in the result
        resultWords[verbPosition] = convertCase(convertedVerb, like: words[verbPosition])
        
        // Handle auxiliary verbs if present
        if verbPosition > 0 {
            let previousWord = words[verbPosition-1].lowercased()
            
            // Remove auxiliaries that would be redundant in past tense
            if ["will", "would", "should", "could", "can", "may", "might", "must"].contains(previousWord) {
                resultWords.remove(at: verbPosition-1)
            }
            // Convert "am/is/are" to "was/were"
            else if ["am", "is", "are"].contains(previousWord) {
                resultWords[verbPosition-1] = previousWord == "are" ? "were" : "was"
                // Handle "going to" pattern
                if words.count > verbPosition+1 && previousWord + " " + verb == "going to" {
                    resultWords.remove(at: verbPosition)
                    resultWords.remove(at: verbPosition-1)
                }
            }
            // Handle "have/has" + past participle
            else if ["have", "has"].contains(previousWord) {
                // The participle is already past tense, so just remove the auxiliary
                resultWords.remove(at: verbPosition-1)
            }
        }
        
        // Format the final sentence
        let result = resultWords.joined(separator: " ")
        
        // Add prefix only if needed
        if !isAlreadyPastTense(title: result) && !hadPrefix {
            return "Completed: " + result
        }
        
        return result
    }
    
    enum VerbForm {
        case base       // Basic form: "run", "jump"
        case presentS   // 3rd person singular present: "runs", "jumps"
        case gerund     // -ing form: "running", "jumping"
        case pastTense  // Simple past: "ran", "jumped"
        case pastPart   // Past participle: "run", "jumped"
        case unknown    // Can't determine or not a verb
    }
    
    // Determine the form of the verb
    private func determineVerbForm(word: String, previous: String?) -> VerbForm {
        if previous == nil {
            // Check for common verb endings
            if word.hasSuffix("ing") {
                return .gerund
            } else if word.hasSuffix("s") && !["is", "was", "has"].contains(word) {
                return .presentS
            } else if word.hasSuffix("ed") && !["need", "reed"].contains(word) {
                return .pastTense
            } else {
                return .base
            }
        } else {
            // Consider the previous word (auxiliary)
            if ["am", "are", "is", "was", "were"].contains(previous) {
                if word.hasSuffix("ing") {
                    return .gerund
                } else {
                    return .base
                }
            } else if ["have", "has", "had"].contains(previous) {
                return .pastPart
            } else if ["will", "would", "should", "could", "can", "may", "might", "must"].contains(previous) {
                return .base
            }
        }
        
        return .unknown
    }
    
    // Convert verb to past tense considering its form
    private func convertVerbToPastTense(verb: String, form: VerbForm) -> String {
        // If it's already past tense or past participle, return as is
        if form == .pastTense || form == .pastPart {
            return verb
        }
        
        // Common irregular verbs with all their forms for better matching
        let irregularVerbs: [String: [VerbForm: String]] = [
            "am": [.base: "am", .presentS: "is", .pastTense: "was", .pastPart: "been", .gerund: "being"],
            "are": [.base: "are", .presentS: "is", .pastTense: "were", .pastPart: "been", .gerund: "being"],
            "is": [.base: "am", .presentS: "is", .pastTense: "was", .pastPart: "been", .gerund: "being"],
            "go": [.base: "go", .presentS: "goes", .pastTense: "went", .pastPart: "gone", .gerund: "going"],
            "do": [.base: "do", .presentS: "does", .pastTense: "did", .pastPart: "done", .gerund: "doing"],
            "make": [.base: "make", .presentS: "makes", .pastTense: "made", .pastPart: "made", .gerund: "making"],
            "get": [.base: "get", .presentS: "gets", .pastTense: "got", .pastPart: "gotten", .gerund: "getting"],
            "take": [.base: "take", .presentS: "takes", .pastTense: "took", .pastPart: "taken", .gerund: "taking"],
            "bring": [.base: "bring", .presentS: "brings", .pastTense: "brought", .pastPart: "brought", .gerund: "bringing"],
            "buy": [.base: "buy", .presentS: "buys", .pastTense: "bought", .pastPart: "bought", .gerund: "buying"],
            "catch": [.base: "catch", .presentS: "catches", .pastTense: "caught", .pastPart: "caught", .gerund: "catching"],
            "come": [.base: "come", .presentS: "comes", .pastTense: "came", .pastPart: "come", .gerund: "coming"],
            "find": [.base: "find", .presentS: "finds", .pastTense: "found", .pastPart: "found", .gerund: "finding"],
            "give": [.base: "give", .presentS: "gives", .pastTense: "gave", .pastPart: "given", .gerund: "giving"],
            "have": [.base: "have", .presentS: "has", .pastTense: "had", .pastPart: "had", .gerund: "having"],
            "know": [.base: "know", .presentS: "knows", .pastTense: "knew", .pastPart: "known", .gerund: "knowing"],
            "meet": [.base: "meet", .presentS: "meets", .pastTense: "met", .pastPart: "met", .gerund: "meeting"],
            "pay": [.base: "pay", .presentS: "pays", .pastTense: "paid", .pastPart: "paid", .gerund: "paying"],
            "read": [.base: "read", .presentS: "reads", .pastTense: "read", .pastPart: "read", .gerund: "reading"],
            "run": [.base: "run", .presentS: "runs", .pastTense: "ran", .pastPart: "run", .gerund: "running"],
            "say": [.base: "say", .presentS: "says", .pastTense: "said", .pastPart: "said", .gerund: "saying"],
            "see": [.base: "see", .presentS: "sees", .pastTense: "saw", .pastPart: "seen", .gerund: "seeing"],
            "send": [.base: "send", .presentS: "sends", .pastTense: "sent", .pastPart: "sent", .gerund: "sending"],
            "speak": [.base: "speak", .presentS: "speaks", .pastTense: "spoke", .pastPart: "spoken", .gerund: "speaking"],
            "tell": [.base: "tell", .presentS: "tells", .pastTense: "told", .pastPart: "told", .gerund: "telling"],
            "think": [.base: "think", .presentS: "thinks", .pastTense: "thought", .pastPart: "thought", .gerund: "thinking"],
            "write": [.base: "write", .presentS: "writes", .pastTense: "wrote", .pastPart: "written", .gerund: "writing"]
        ]
        
        // Simple map for irregular verbs in third person present
        let irregularPresentsMap: [String: String] = [
            "goes": "went",
            "does": "did",
            "makes": "made",
            "gets": "got",
            "takes": "took",
            "brings": "brought",
            "buys": "bought",
            "catches": "caught",
            "comes": "came",
            "finds": "found",
            "gives": "gave",
            "has": "had",
            "knows": "knew",
            "meets": "met",
            "pays": "paid",
            "reads": "read",
            "runs": "ran",
            "says": "said",
            "sees": "saw",
            "sends": "sent",
            "speaks": "spoke",
            "tells": "told",
            "thinks": "thought",
            "writes": "wrote"
        ]
        
        // Extended map of all irregular verbs in base form
        let irregularVerbsSimpleMap: [String: String] = [
            "am": "was",
            "are": "were",
            "is": "was",
            "go": "went",
            "do": "did",
            "make": "made",
            "get": "got",
            "take": "took",
            "bring": "brought",
            "buy": "bought",
            "catch": "caught",
            "come": "came",
            "find": "found",
            "give": "gave",
            "have": "had",
            "know": "knew",
            "meet": "met",
            "pay": "paid",
            "read": "read",
            "run": "ran",
            "say": "said",
            "see": "saw",
            "send": "sent",
            "speak": "spoke",
            "tell": "told",
            "think": "thought",
            "write": "wrote",
            "understand": "understood",
            "stand": "stood",
            "sit": "sat",
            "set": "set",
            "put": "put",
            "let": "let",
            "leave": "left",
            "keep": "kept",
            "hold": "held",
            "hurt": "hurt",
            "hit": "hit",
            "feed": "fed",
            "feel": "felt",
            "drive": "drove",
            "drink": "drank",
            "draw": "drew",
            "dream": "dreamt",
            "cost": "cost",
            "choose": "chose",
            "build": "built",
            "break": "broke",
            "blow": "blew",
            "begin": "began",
            "become": "became",
            "bear": "bore",
            "be": "was"
        ]
        
        // Handle -ing forms (gerunds)
        if form == .gerund {
            // Strip -ing and try to match with irregular verbs
            let stem = String(verb.dropLast(3))
            
            // Check if the stem is in our irregular verbs dictionary
            for (_, forms) in irregularVerbs {
                if forms[.gerund] == verb {
                    return forms[.pastTense] ?? verb
                }
            }
            
            // Handle doubled consonant + ing (e.g., "running" -> "ran")
            if stem.count > 1 && stem.last == stem.dropLast().last {
                let base = String(stem.dropLast())
                if let pastTense = irregularVerbsSimpleMap[base] {
                    return pastTense
                }
            }
            
            // Regular verbs: add "ed" to the stem after removing -ing
            if stem.hasSuffix("e") {
                return stem + "d"
            } else {
                return stem + "ed"
            }
        }
        
        // Handle 3rd person present forms (ends with s)
        if form == .presentS {
            // First check if it's a known irregular
            if let pastTense = irregularPresentsMap[verb] {
                return pastTense
            }
            
            // Regular verbs: remove s and add ed
            let stem = verb.hasSuffix("es") ? String(verb.dropLast(2)) : String(verb.dropLast())
            
            if stem.hasSuffix("e") {
                return stem + "d"
            } else if stem.hasSuffix("y") && stem.count > 1 {
                return String(stem.dropLast()) + "ied"
            } else {
                return stem + "ed"
            }
        }
        
        // Handle base forms
        if form == .base {
            // Check if the verb is in our irregular verbs map
            if let pastTense = irregularVerbsSimpleMap[verb] {
                return pastTense
            }
            
            // Regular verb handling
            if verb.hasSuffix("e") {
                // For verbs ending in 'e', just add 'd' (like "bake" -> "baked")
                return verb + "d"
            }
            else if verb.hasSuffix("y") && verb.count > 1 {
                // For verbs ending in 'y', change to 'ied' (like "try" -> "tried")
                let index = verb.index(before: verb.endIndex)
                return verb[..<index] + "ied"
            }
            else {
                // For most other regular verbs, just add 'ed' (like "talk" -> "talked")
                return verb + "ed"
            }
        }
        
        // Default fallback
        return verb
    }
    
    // Helper to preserve case of original word
    private func convertCase(_ word: String, like original: String) -> String {
        // If original is all uppercase, convert new word to uppercase
        if original.uppercased() == original {
            return word.uppercased()
        }
        
        // If original has first letter capitalized
        if let firstChar = original.first, firstChar.isUppercase {
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        
        // Otherwise return as is (presumably lowercase)
        return word
    }
}
