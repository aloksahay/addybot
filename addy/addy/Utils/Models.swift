struct TaskRecommendation: Codable {
    let taskName: String
    let sessionDuration: Int
    let priority: Int
    let reason: String
    let currentCompletion: Double
    let targetCompletion: Double
    let deadline: String?
}

struct OverallProgress: Codable {
    let completion: Double
    let totalTasks: Int
    let completedTasks: Int
    let inProgressTasks: Int
    let notStartedTasks: Int
    let tasksWithDeadlines: Int
}

struct RecommendationResponse: Codable {
    let overallProgress: OverallProgress
    let recommendations: [TaskRecommendation]
} 