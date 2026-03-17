<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreEventRegistrationRequest;
use App\Models\Event;
use App\Models\EventRegistration;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Str;
use Illuminate\View\View;

class EventRegistrationController extends Controller
{
    public function create(Event $event): View|RedirectResponse
    {
        if (! $event->isRegistrationOpen()) {
            return redirect()->route('events.show', $event)
                ->with('error', 'Registration is closed for this event.');
        }

        if ($event->isFull()) {
            return redirect()->route('events.show', $event)
                ->with('error', 'This event is full.');
        }

        $existingRegistration = EventRegistration::query()
            ->where('event_id', $event->id)
            ->where('user_id', auth()->id())
            ->first();

        if ($existingRegistration) {
            return redirect()->route('events.show', $event)
                ->with('info', 'You are already registered for this event.');
        }

        $user = auth()->user();

        return view('events.register', compact('event', 'user'));
    }

    public function store(StoreEventRegistrationRequest $request, Event $event): RedirectResponse
    {
        if (! $event->isRegistrationOpen() || $event->isFull()) {
            return redirect()->route('events.show', $event)
                ->with('error', 'Registration is no longer available.');
        }

        $existingRegistration = EventRegistration::query()
            ->where('event_id', $event->id)
            ->where('user_id', auth()->id())
            ->first();

        if ($existingRegistration) {
            return redirect()->route('events.show', $event)
                ->with('info', 'You are already registered.');
        }

        $data = $request->validated();
        $data['event_id'] = $event->id;
        $data['user_id'] = auth()->id();
        $data['amount'] = $event->fee ?? 0;
        $data['qr_code'] = Str::uuid()->toString();

        EventRegistration::query()->create($data);

        return redirect()->route('events.registration.confirmation', $event)
            ->with('success', 'Successfully registered! Your QR code has been generated.');
    }

    public function confirmation(Event $event): View|RedirectResponse
    {
        $registration = EventRegistration::query()
            ->where('event_id', $event->id)
            ->where('user_id', auth()->id())
            ->first();

        if (! $registration) {
            return redirect()->route('events.show', $event)
                ->with('error', 'You are not registered for this event.');
        }

        return view('events.confirmation', compact('event', 'registration'));
    }

    public function qrCode(Event $event): View|RedirectResponse
    {
        $registration = EventRegistration::query()
            ->where('event_id', $event->id)
            ->where('user_id', auth()->id())
            ->first();

        if (! $registration) {
            return redirect()->route('events.show', $event)
                ->with('error', 'You are not registered for this event.');
        }

        return view('events.qr-code', compact('event', 'registration'));
    }
}
