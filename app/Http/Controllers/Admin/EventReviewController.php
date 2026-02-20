<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\ReviewEventRequest;
use App\Models\Event;
use App\Models\EventReview;
use Illuminate\Http\RedirectResponse;

class EventReviewController extends Controller
{
    public function store(ReviewEventRequest $request, Event $event): RedirectResponse
    {
        $validated = $request->validated();

        $event->update([
            'status' => $validated['decision'],
        ]);

        EventReview::query()->create([
            'event_id' => $event->id,
            'admin_id' => $request->user()->id,
            'decision' => $validated['decision'],
            'feedback' => $validated['feedback'] ?? null,
            'reviewed_at' => now(),
        ]);

        return back()->with('status', 'Event review saved successfully.');
    }
}
