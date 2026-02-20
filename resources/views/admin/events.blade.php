<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-4">
            <h2 class="font-semibold text-xl text-gray-800 leading-tight">All Events</h2>
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
                            <th class="px-4 py-3 text-left">Title</th>
                            <th class="px-4 py-3 text-left">Organizer</th>
                            <th class="px-4 py-3 text-left">Status</th>
                            <th class="px-4 py-3 text-left">Review</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($events as $event)
                            <tr class="border-t">
                                <td class="px-4 py-3">{{ $event->title }}</td>
                                <td class="px-4 py-3">{{ $event->organizer?->email ?? 'N/A' }}</td>
                                <td class="px-4 py-3">{{ $event->status }}</td>
                                <td class="px-4 py-3 space-y-2">
                                    <form method="POST" action="{{ route('admin.events.review', $event) }}" class="flex flex-wrap gap-2">
                                        @csrf
                                        <input type="hidden" name="decision" value="approved">
                                        <input type="text" name="feedback" placeholder="Optional feedback" class="border rounded-md px-2 py-1">
                                        <button class="px-3 py-1.5 border rounded-md">Approve</button>
                                    </form>
                                    <form method="POST" action="{{ route('admin.events.review', $event) }}" class="flex flex-wrap gap-2">
                                        @csrf
                                        <input type="hidden" name="decision" value="rejected">
                                        <input type="text" name="feedback" placeholder="Reason for reject" class="border rounded-md px-2 py-1">
                                        <button class="px-3 py-1.5 border rounded-md text-red-600 border-red-200">Reject</button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="4" class="px-4 py-6 text-center text-gray-500">No events available yet.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{ $events->links() }}
        </div>
    </div>
</x-app-layout>
