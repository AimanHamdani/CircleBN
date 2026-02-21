<?php

namespace App\Http\Controllers;

use App\Models\Event;
use App\Models\EventRegistration;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class CheckInController extends Controller
{
    public function index(Event $event): View
    {
        if ($event->user_id !== auth()->id()) {
            abort(403);
        }

        $event->load('registrations.user');
        $event->loadCount('registrations');
        $checkedInCount = $event->registrations->whereNotNull('checked_in_at')->count();

        return view('events.manage.checkin', compact('event', 'checkedInCount'));
    }

    public function scan(Request $request, Event $event): JsonResponse
    {
        if ($event->user_id !== auth()->id()) {
            return response()->json(['success' => false, 'message' => 'Unauthorized.'], 403);
        }

        $request->validate([
            'qr_code' => ['required', 'string'],
        ]);

        $registration = EventRegistration::query()
            ->where('event_id', $event->id)
            ->where('qr_code', $request->qr_code)
            ->with('user')
            ->first();

        if (! $registration) {
            return response()->json([
                'success' => false,
                'message' => 'Participant not found. This QR code is not registered for this event.',
            ]);
        }

        if ($registration->checked_in_at) {
            return response()->json([
                'success' => false,
                'message' => 'Participant '.$registration->user->name.' has already checked in.',
                'participant' => $registration->user->name,
                'already_checked_in' => true,
            ]);
        }

        $registration->update(['checked_in_at' => now()]);

        $totalRegistered = $event->registrations()->count();
        $totalCheckedIn = $event->registrations()->whereNotNull('checked_in_at')->count();

        return response()->json([
            'success' => true,
            'message' => 'Successfully checked in: '.$registration->user->name,
            'participant' => $registration->user->name,
            'total_registered' => $totalRegistered,
            'total_checked_in' => $totalCheckedIn,
        ]);
    }

    public function manualCheckIn(Request $request, Event $event): JsonResponse
    {
        if ($event->user_id !== auth()->id()) {
            return response()->json(['success' => false, 'message' => 'Unauthorized.'], 403);
        }

        $request->validate([
            'registration_id' => ['required', 'integer'],
        ]);

        $registration = EventRegistration::query()
            ->where('event_id', $event->id)
            ->where('id', $request->registration_id)
            ->with('user')
            ->first();

        if (! $registration) {
            return response()->json(['success' => false, 'message' => 'Registration not found.']);
        }

        if ($registration->checked_in_at) {
            return response()->json([
                'success' => false,
                'message' => $registration->user->name.' has already checked in.',
            ]);
        }

        $registration->update(['checked_in_at' => now()]);

        return response()->json([
            'success' => true,
            'message' => 'Successfully checked in: '.$registration->user->name,
        ]);
    }
}
