<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-4">
            <h2 class="font-semibold text-xl text-gray-800 leading-tight">All Users</h2>
            <a href="{{ route('admin.dashboard') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
                Back to Admin Dashboard
            </a>
        </div>
    </x-slot>

    <div class="py-10">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-6">
            @if (session('status'))
                <div class="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg">
                    {{ session('status') }}
                </div>
            @endif

            <div class="bg-white border border-gray-200 rounded-lg overflow-x-auto">
                <table class="min-w-full text-sm">
                    <thead class="bg-gray-50 text-gray-600">
                        <tr>
                            <th class="px-4 py-3 text-left">Name</th>
                            <th class="px-4 py-3 text-left">Email</th>
                            <th class="px-4 py-3 text-left">Status</th>
                            <th class="px-4 py-3 text-left">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($users as $user)
                            <tr class="border-t">
                                <td class="px-4 py-3">{{ $user->name }}</td>
                                <td class="px-4 py-3">{{ $user->email }}</td>
                                <td class="px-4 py-3">{{ $user->status }}</td>
                                <td class="px-4 py-3">
                                    <form method="POST" action="{{ route('admin.users.moderate', $user) }}" class="flex flex-wrap gap-2">
                                        @csrf
                                        <input type="hidden" name="action" value="warning">
                                        <button class="px-3 py-1.5 border rounded-md">Warning</button>
                                    </form>
                                    <form method="POST" action="{{ route('admin.users.moderate', $user) }}" class="flex flex-wrap gap-2 mt-2">
                                        @csrf
                                        <input type="hidden" name="action" value="suspend">
                                        <button class="px-3 py-1.5 border rounded-md">Suspend</button>
                                    </form>
                                    <form method="POST" action="{{ route('admin.users.moderate', $user) }}" class="flex flex-wrap gap-2 mt-2" onsubmit="return confirm('Delete this account?')">
                                        @csrf
                                        <input type="hidden" name="action" value="delete">
                                        <button class="px-3 py-1.5 border rounded-md text-red-600 border-red-200">Delete</button>
                                    </form>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>

            {{ $users->links() }}

            <div class="bg-white border border-gray-200 rounded-lg p-6">
                <h3 class="text-lg font-semibold mb-3">User Reported (Review Queue)</h3>
                <div class="space-y-3 text-sm">
                    @forelse ($reports as $report)
                        <div class="border rounded-md p-3">
                            <p><strong>Reporter:</strong> {{ $report->reporter?->email ?? 'N/A' }}</p>
                            <p><strong>Reported User:</strong> {{ $report->reportedUser?->email ?? 'N/A' }}</p>
                            <p><strong>Reason:</strong> {{ $report->reason }}</p>
                            <p><strong>Status:</strong> {{ $report->status }}</p>
                        </div>
                    @empty
                        <p>No reports yet.</p>
                    @endforelse
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
