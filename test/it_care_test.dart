import 'package:flutter_test/flutter_test.dart';
import 'package:baknusmail/models/it_care_models.dart';
import 'package:baknusmail/services/it_care_service.dart';

void main() {
  group('BaknusITCare Models & Logic Tests', () {
    test('ITCareUser parsing & role checks', () {
      final pelaporJson = {
        'userId': 'usr-1',
        'name': 'Ahmad Fauzi',
        'email': 'ahmad@smkbn666.sch.id',
        'role': 'Pelapor',
      };
      final pelapor = ITCareUser.fromJson(pelaporJson);
      expect(pelapor.id, 'usr-1');
      expect(pelapor.name, 'Ahmad Fauzi');
      expect(pelapor.role, 'Pelapor');
      expect(pelapor.isTechnician, false);

      final teknisiJson = {
        'userId': 'usr-2',
        'name': 'Frian Prianas',
        'email': 'frian@smkbn666.sch.id',
        'role': 'Teknisi',
      };
      final teknisi = ITCareUser.fromJson(teknisiJson);
      expect(teknisi.isTechnician, true);
    });

    test('TicketItem and TicketComment parsing', () {
      final ticketJson = {
        "id": 1,
        "ticketCode": "BID-101",
        "title": "[BaknusID - Website Baknus] Kendala Akses Layanan Digital",
        "description": "Kendala pada layanan Website Baknus.",
        "category": "Layanan BaknusID",
        "location": "Online / Layanan Cloud BaknusID",
        "priority": "Sedang",
        "status": "Selesai",
        "requesterId": "eb924f60-4b83-47e9-b3da-8a418065e97e",
        "requesterName": "Septian",
        "requesterEmail": "septian@smk.baktinusantara666.sch.id",
        "assignedTechnicianName": "Belum Ditugaskan",
        "createdAt": "2026-09-08T08:51:46.2867978",
        "dueDate": "2026-09-08T16:51:46.2867202",
        "isOverdue": false,
        "rating": 5,
        "feedbackComments": "Mantap cepat sekali",
        "comments": [
          {
            "id": 1,
            "userId": "824cf208",
            "userName": "Frian Prianas",
            "userRole": "Teknisi",
            "message": "Sekarang sedang diperbaiki",
            "isInternal": false,
            "createdAt": "2026-09-08T08:54:28.6261204"
          }
        ]
      };

      final ticket = TicketItem.fromJson(ticketJson);
      expect(ticket.id, 1);
      expect(ticket.ticketCode, 'BID-101');
      expect(ticket.isResolved, true);
      expect(ticket.rating, 5);
      expect(ticket.feedbackComments, 'Mantap cepat sekali');
      expect(ticket.comments.length, 1);
      expect(ticket.comments.first.userName, 'Frian Prianas');
      expect(ticket.comments.first.isTechnician, true);
    });

    test('MetaOptions defaults and parsing', () {
      final defaultOpts = MetaOptions.defaultOptions();
      expect(defaultOpts.locations.length, 19);
      expect(defaultOpts.locations.first, '1. Ruang Workshop');
      expect(defaultOpts.locations.last, '19. Lainnya');
      expect(defaultOpts.services, contains('Internet'));
      expect(defaultOpts.services, contains('BaknusID'));
      expect(defaultOpts.internetSubIssues.length, 3);
      expect(defaultOpts.baknusIdApps, contains('WebsiteBaknus'));
      expect(defaultOpts.baknusIdApps, contains('Baknusmail'));
    });

    test('KpiDashboard parsing', () {
      final kpiJson = {
        "totalTickets": 3,
        "newTickets": 1,
        "inProgressTickets": 1,
        "pendingPartsTickets": 0,
        "resolvedTickets": 1,
        "overdueSlaTickets": 0,
        "averageRating": 4.5,
        "categoryBreakdown": {
          "Layanan BaknusID": 1,
          "Layanan Internet": 2
        }
      };

      final kpi = KpiDashboard.fromJson(kpiJson);
      expect(kpi.totalTickets, 3);
      expect(kpi.newTickets, 1);
      expect(kpi.inProgressTickets, 1);
      expect(kpi.resolvedTickets, 1);
      expect(kpi.averageRating, 4.5);
      expect(kpi.categoryBreakdown['Layanan Internet'], 2);
    });

    test('ITCareService defaults', () {
      final service = ITCareService();
      expect(service.baseUrl, 'https://baknusitcare.smkbn666.sch.id/api');
    });

    test('ITTechnicianStaff parsing and properties from /api/technicians', () {
      final json = {
        'id': '824cf208-2412-4379-9bd0-e0f4684cb9ef',
        'fullName': 'Frian Prianas',
        'email': 'frian_p@smk.baktinusantara666.sch.id',
        'phoneNumber': '08123456789',
        'role': 'Teknisi',
        'roleLabel': 'Petugas IT (Teknisi)',
        'department': 'Guru',
        'activeTicketsHandled': 2,
        'totalResolvedTickets': 14,
      };

      final staff = ITTechnicianStaff.fromJson(json);
      expect(staff.id, '824cf208-2412-4379-9bd0-e0f4684cb9ef');
      expect(staff.fullName, 'Frian Prianas');
      expect(staff.email, 'frian_p@smk.baktinusantara666.sch.id');
      expect(staff.role, 'Teknisi');
      expect(staff.roleLabel, 'Petugas IT (Teknisi)');
      expect(staff.department, 'Guru');
      expect(staff.activeTicketsHandled, 2);
      expect(staff.totalResolvedTickets, 14);
      expect(staff.avatarInitials, 'FP');
      expect(staff.isAdmin, false);

      final contact = staff.toContact();
      expect(contact.name, 'Frian Prianas');
      expect(contact.email, 'frian_p@smk.baktinusantara666.sch.id');
      expect(contact.avatarInitials, 'FP');
    });

    test('ITTechnicianContact defaults and BaknusChat integration info', () {
      expect(ITTechnicianContact.defaultStaff.length, 3);
      final frian = ITTechnicianContact.defaultStaff.first;
      expect(frian.name, 'Frian Prianas');
      expect(frian.email, 'frian_p@smk.baktinusantara666.sch.id');
      expect(frian.avatarInitials, 'FP');

      final septian = ITTechnicianContact.defaultStaff[1];
      expect(septian.name, 'Septian');
      expect(septian.email, 'septian@smk.baktinusantara666.sch.id');
    });
  });
}
