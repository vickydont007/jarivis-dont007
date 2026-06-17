import '../memory_system.dart';
import 'calendar_service.dart';
import 'email_service.dart';
import 'research_service.dart';
import 'multi_agent_orchestrator.dart';
import '../auth/auth_provider.dart';

class WorkspaceLoader {
  MemorySystem? _memorySystem;
  CalendarService? _calendarService;
  EmailService? _emailService;
  ResearchService? _researchService;
  MultiAgentOrchestrator? _orchestrator;

  WorkspaceLoader() {
    _registerCallbacks();
  }

  void init({
    MemorySystem? memorySystem,
    CalendarService? calendarService,
    EmailService? emailService,
    ResearchService? researchService,
    MultiAgentOrchestrator? orchestrator,
  }) {
    _memorySystem = memorySystem;
    _calendarService = calendarService;
    _emailService = emailService;
    _researchService = researchService;
    _orchestrator = orchestrator;
  }

  void loadUserData(String userId) {
    _memorySystem?.setUserId(userId);
    _calendarService?.setUserId(userId);
    _emailService?.setUserId(userId);
    _researchService?.setUserId(userId);
    _orchestrator?.setUserId(userId);
  }

  Future<void> clearUserData() async {
    _memorySystem?.setUserId('');
    _calendarService?.setUserId('');
    _emailService?.setUserId('');
    _researchService?.setUserId('');
    _orchestrator?.setUserId('');
  }

  void _registerCallbacks() {
    setLogoutCleanup(() async {
      await clearUserData();
    });
    setLoginLoadCallback((String userId) async {
      loadUserData(userId);
    });
  }

  void dispose() {
    _memorySystem = null;
    _calendarService = null;
    _emailService = null;
    _researchService = null;
    _orchestrator = null;
  }
}
