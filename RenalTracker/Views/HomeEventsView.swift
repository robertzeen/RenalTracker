//
//  HomeEventsView.swift
//  RenalTracker
//

import SwiftUI

struct HomeEventsView: View {
    let profile: UserProfile?
    let currentTime: Date
    let onShowDoctorVisits: (() -> Void)?
    @Binding var isShowingDoctorDateSheet: Bool
    @Binding var isShowingLabTestDateSheet: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ближайшие события")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                if onShowDoctorVisits != nil {
                    Button("Журнал →") { onShowDoctorVisits?() }
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)

            Divider()

            doctorEventRow

            Divider()

            labEventRow
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Event rows

    private var doctorEventRow: some View {
        let appointment = profile?.nextDoctorAppointment
        let name = profile?.nextDoctorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = (name?.isEmpty == false ? name : nil) ?? "Приём у врача"

        return HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("👩‍⚕️")
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: 14, weight: .medium))
                if let appt = appointment {
                    Text(DateFormatter.russianDateTime.string(from: appt))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Дата не указана")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let appt = appointment {
                eventBadge(for: appt)
            }
            Button { isShowingDoctorDateSheet = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    private var labEventRow: some View {
        let labDate = profile?.nextLabTest

        return HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("🧪")
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Сдача анализов")
                    .font(.system(size: 14, weight: .medium))
                if let lab = labDate {
                    Text(DateFormatter.russianDateTime.string(from: lab))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Дата не указана")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let lab = labDate {
                eventBadge(for: lab)
            }
            Button { isShowingLabTestDateSheet = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    // MARK: - Event status badge

    private enum EventStatus: Equatable {
        case passed, today, tomorrow
        case upcoming(days: Int)
    }

    private func eventStatus(for date: Date) -> EventStatus {
        let now = currentTime
        if now > date.addingTimeInterval(3600) { return .passed }
        let diffDays = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        switch diffDays {
        case 0: return .today
        case 1: return .tomorrow
        default: return .upcoming(days: diffDays)
        }
    }

    @ViewBuilder
    private func eventBadge(for date: Date) -> some View {
        switch eventStatus(for: date) {
        case .passed:
            Text("Прошёл")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.systemGray5))
                .cornerRadius(10)
        case .today:
            Text("Сегодня!")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)
        case .tomorrow:
            Text("Завтра!")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)
        case .upcoming(let days):
            Text("Через \(days) дней")
                .font(.system(size: 11))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
        }
    }
}
