import '../../data/models/project_model.dart';
import '../../data/models/worker_model.dart';

abstract class IProjectRepository {
  Future<List<Project>> getProjects(String orgId);
  Future<Project?> getProject(int id);
  Future<int> createProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(int id);
  
  // New Worker Management Methods
  Future<List<Worker>> getProjectWorkers(int projectId);
  Future<List<Worker>> getAvailableWorkers(int projectId);
  Future<List<Worker>> getProjectCrewMembers(int projectId, int crewId);
  Future<List<Worker>> getProjectWorkersWithoutCrew(int projectId);
  Future<void> addWorkersToProject(int projectId, List<int> workerIds);
  Future<void> removeWorkerFromProject(int projectId, int workerId);
  Future<void> assignWorkerToCrew(int projectId, int workerId, int? crewId);
}
