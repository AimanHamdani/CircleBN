<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\ModerateUserRequest;
use App\Models\User;
use App\Models\UserModeration;
use Illuminate\Http\RedirectResponse;

class UserModerationController extends Controller
{
    public function store(ModerateUserRequest $request, User $user): RedirectResponse
    {
        $validated = $request->validated();

        if ($request->user()->is($user) && $validated['action'] !== 'warning') {
            return back()->with('status', 'You cannot suspend or delete your own account.');
        }

        UserModeration::query()->create([
            'user_id' => $user->id,
            'admin_id' => $request->user()->id,
            'report_id' => $validated['report_id'] ?? null,
            'action' => $validated['action'],
            'feedback' => $validated['feedback'] ?? null,
            'status' => 'completed',
            'acted_at' => now(),
        ]);

        if ($validated['action'] === 'warning') {
            return back()->with('status', 'Warning recorded successfully.');
        }

        if ($validated['action'] === 'suspend') {
            $user->update([
                'status' => 'suspended',
                'suspended_at' => now(),
            ]);

            return back()->with('status', 'User suspended successfully.');
        }

        $user->delete();

        return back()->with('status', 'User account deleted successfully.');
    }
}
