<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreAnnouncementRequest;
use App\Http\Requests\UpdateEventRequest;
use App\Models\Event;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;

class EventManagementController extends Controller
{
    public function index(): View
    {
        $events = Event::query()
            ->where('user_id', auth()->id())
            ->withCount('registrations')
            ->orderBy('created_at', 'desc')
            ->get();

        return view('events.manage.index', compact('events'));
    }

    public function show(Event $event): View|RedirectResponse
    {
        if ($event->user_id !== auth()->id()) {
            abort(403);
        }

        $event->load(['registrations.user', 'announcements']);
        $event->loadCount('registrations');

        return view('events.manage.show', compact('event'));
    }

    public function edit(Event $event): View
    {
        if ($event->user_id !== auth()->id()) {
            abort(403);
        }

        return view('events.manage.edit', compact('event'));
    }

    public function update(UpdateEventRequest $request, Event $event): RedirectResponse
    {
        $data = $request->validated();

        if ($request->hasFile('image')) {
            $data['image'] = $request->file('image')->store('events', 'public');
        }

        $event->update($data);

        return redirect()->route('events.manage.show', $event)
            ->with('success', 'Event updated successfully.');
    }

    public function registrations(Event $event): View
    {
        if ($event->user_id !== auth()->id()) {
            abort(403);
        }

        $event->load('registrations.user');

        return view('events.manage.registrations', compact('event'));
    }

    public function analytics(Event $event): View
    {
        if ($event->user_id !== auth()->id()) {
            abort(403);
        }

        $event->load('registrations');

        $totalRegistered = $event->registrations->count();
        $checkedIn = $event->registrations->whereNotNull('checked_in_at')->count();
        $droppedOff = $event->registrations->where('dropped_off', true)->count();

        $genderDistribution = $event->registrations->groupBy('gender')->map->count();
        $ageRanges = $this->calculateAgeRanges($event->registrations);
        $revenue = $event->registrations->sum('amount');

        return view('events.manage.analytics', compact(
            'event',
            'totalRegistered',
            'checkedIn',
            'droppedOff',
            'genderDistribution',
            'ageRanges',
            'revenue',
        ));
    }

    public function closeRegistration(Event $event): RedirectResponse
    {
        if ($event->user_id !== auth()->id()) {
            abort(403);
        }

        $event->update(['registration_open' => false]);

        return redirect()->route('events.manage.show', $event)
            ->with('success', 'Registration has been closed.');
    }

    public function openRegistration(Event $event): RedirectResponse
    {
        if ($event->user_id !== auth()->id()) {
            abort(403);
        }

        $event->update(['registration_open' => true]);

        return redirect()->route('events.manage.show', $event)
            ->with('success', 'Registration has been opened.');
    }

    public function storeAnnouncement(StoreAnnouncementRequest $request, Event $event): RedirectResponse
    {
        $event->announcements()->create($request->validated());

        return redirect()->route('events.manage.show', $event)
            ->with('success', 'Announcement sent successfully.');
    }

    /**
     * @param  \Illuminate\Support\Collection<int, \App\Models\EventRegistration>  $registrations
     * @return array<string, int>
     */
    private function calculateAgeRanges($registrations): array
    {
        $ranges = [
            'Under 18' => 0,
            '18-25' => 0,
            '26-35' => 0,
            '36-45' => 0,
            '46-55' => 0,
            '56+' => 0,
        ];

        foreach ($registrations as $registration) {
            $age = $registration->age;

            if (! $age) {
                continue;
            }

            if ($age < 18) {
                $ranges['Under 18']++;
            } elseif ($age <= 25) {
                $ranges['18-25']++;
            } elseif ($age <= 35) {
                $ranges['26-35']++;
            } elseif ($age <= 45) {
                $ranges['36-45']++;
            } elseif ($age <= 55) {
                $ranges['46-55']++;
            } else {
                $ranges['56+']++;
            }
        }

        return $ranges;
    }
}
