<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreEventRequest;
use App\Models\Event;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class EventController extends Controller
{
    public function index(Request $request): View
    {
        $query = Event::query()
            ->where('status', 'approved')
            ->with('organizer')
            ->withCount('registrations');

        if ($request->filled('search')) {
            $query->where(function ($q) use ($request) {
                $q->where('title', 'like', '%'.$request->search.'%')
                    ->orWhere('location', 'like', '%'.$request->search.'%');
            });
        }

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        $events = $query->orderBy('starts_at', 'asc')->paginate(12);

        return view('events.index', compact('events'));
    }

    public function show(Event $event): View
    {
        $event->load(['organizer', 'registrations.user', 'announcements']);
        $event->loadCount('registrations');

        $isRegistered = false;
        $registration = null;

        if (auth()->check()) {
            $registration = $event->registrations()
                ->where('user_id', auth()->id())
                ->first();
            $isRegistered = (bool) $registration;
        }

        return view('events.show', compact('event', 'isRegistered', 'registration'));
    }

    public function create(): View
    {
        return view('events.create');
    }

    public function store(StoreEventRequest $request): RedirectResponse
    {
        $data = $request->validated();
        $data['user_id'] = auth()->id();
        $data['status'] = 'pending';
        $data['registration_open'] = true;

        if ($request->hasFile('image')) {
            $data['image'] = $request->file('image')->store('events', 'public');
        }

        $event = Event::query()->create($data);

        return redirect()->route('events.manage.show', $event)
            ->with('success', 'Event created successfully! It will be visible once approved.');
    }
}
