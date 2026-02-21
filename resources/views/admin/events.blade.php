<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-4">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">All Events</h2>
            <a href="{{ route('admin.dashboard') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-100 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700">
                Back to Admin Dashboard
            </a>
        </div>
    </x-slot>

    <div class="py-10">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-6">
            @if (session('status'))
                <div class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-700 text-green-700 dark:text-green-300 px-4 py-3 rounded-lg">
                    {{ session('status') }}
                </div>
            @endif

            <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg overflow-x-auto">
                <table class="min-w-full text-sm text-gray-800 dark:text-gray-100">
                    <thead class="bg-gray-50 dark:bg-gray-700 text-gray-600 dark:text-gray-200">
                        <tr>
                            <th class="px-4 py-3 text-left">Title</th>
                            <th class="px-4 py-3 text-left">Organizer</th>
                            <th class="px-4 py-3 text-left">Status</th>
                            <th class="px-4 py-3 text-left">Review</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($events as $event)
                            <tr class="border-t dark:border-gray-700">
                                <td class="px-4 py-3">{{ $event->title }}</td>
                                <td class="px-4 py-3">{{ $event->organizer?->email ?? 'N/A' }}</td>
                                <td class="px-4 py-3">{{ $event->status }}</td>
                                <td class="px-4 py-3 space-y-2">
                                    <form method="POST" action="{{ route('admin.events.review', $event) }}" class="flex flex-wrap gap-2">
                                        @csrf
                                        <input type="hidden" name="decision" value="approved">
                                        <input type="text" name="feedback" placeholder="Optional feedback" class="border border-gray-300 dark:border-gray-600 rounded-md px-2 py-1 bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
                                        <button class="px-3 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md dark:text-gray-100 dark:bg-gray-900">Approve</button>
                                    </form>
                                    <form method="POST" action="{{ route('admin.events.review', $event) }}" class="flex flex-wrap gap-2">
                                        @csrf
                                        <input type="hidden" name="decision" value="rejected">
                                        <input type="text" name="feedback" placeholder="Reason for reject" class="border border-gray-300 dark:border-gray-600 rounded-md px-2 py-1 bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
                                        <button class="px-3 py-1.5 border rounded-md text-red-600 border-red-200 dark:border-red-500/40 dark:text-red-300 dark:bg-gray-900">Reject</button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="4" class="px-4 py-6 text-center text-gray-500 dark:text-gray-300">No events available yet.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            {{ $events->links() }}
        </div>
    </div>
</x-app-layout>
